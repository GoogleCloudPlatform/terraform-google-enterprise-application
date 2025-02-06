/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Setup

locals {
  subnet_ip                  = "10.3.0.0/24"
  proxy_ip                   = "10.3.0.10"
  private_service_connect_ip = "10.2.0.0"

  peering_address = "192.165.0.0"

  network_name = element(split("/", module.vpc.network_id), index(split("/", module.vpc.network_id), "networks") + 1, )
}
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id                             = var.project_id
  network_name                           = "eab-vpc-${local.env}"
  shared_vpc_host                        = false
  delete_default_internet_gateway_routes = "true"

  subnets = [
    {
      subnet_name           = "eab-${local.short_env}-${var.region}"
      subnet_ip             = local.subnet_ip
      subnet_region         = var.region
      subnet_private_access = true
    },
  ]

  secondary_ranges = {
    "eab-${local.short_env}-${var.region}" = [
      {
        range_name    = "eab-${local.short_env}-${var.region}-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-${local.short_env}-${var.region}-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }

  firewall_rules = [
    # {
    #   name      = "fw-e-shared-restricted-65535-e-d-all-all-all"
    #   direction = "EGRESS"
    #   priority  = 65535

    #   log_config = {
    #     metadata = "INCLUDE_ALL_METADATA"
    #   }

    #   deny = [{
    #     protocol = "all"
    #     ports    = null
    #   }]

    #   ranges = ["0.0.0.0/0"]
    # },
    {
      name      = "fw-e-shared-restricted-65534-e-a-allow-google-apis-all-tcp-443"
      direction = "EGRESS"
      priority  = 65534

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      deny = []
      allow = [{
        protocol = "tcp"
        ports    = ["443"]
      }]

      ranges = [local.private_service_connect_ip]
    }
  ]
}

resource "google_dns_policy" "default_policy" {
  project                   = var.project_id
  name                      = "dp-b-cbpools-default-policy"
  enable_inbound_forwarding = true
  enable_logging            = true
  networks {
    network_url = module.vpc.network_self_link
  }
}

resource "google_compute_global_address" "worker_pool_range" {
  name          = "ga-b-cbpools-worker-pool-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.peering_address
  prefix_length = "24"
  network       = module.vpc.network_id
  depends_on    = [module.vpc]
}

resource "google_service_networking_connection" "private_service_connect" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_pool_range.name, google_compute_global_address.private_ip_allocation.name]
  depends_on              = [module.vpc]
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  project              = var.project_id
  peering              = google_service_networking_connection.private_service_connect.peering
  network              = local.network_name
  import_custom_routes = true
  export_custom_routes = true
  depends_on           = [module.vpc]
}

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  project            = module.vpc.project_id
  disable_on_destroy = false
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = module.vpc.network_name

  rules = [{
    name                    = "fw-b-cbpools-100-i-a-all-all-all-service-networking"
    description             = "allow ingress from the IPs configured for service networking"
    direction               = "INGRESS"
    priority                = 100
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_pool_range.address}/${google_compute_global_address.worker_pool_range.prefix_length}"]

    allow = [{
      protocol = "all"
      ports    = null
    }]

    deny = []

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
  depends_on = [module.vpc]
}

module "private_service_connect" {
  source                     = "terraform-google-modules/network/google//modules/private-service-connect"
  version                    = "~> 10.0"
  project_id                 = var.project_id
  network_self_link          = module.vpc.network_self_link
  private_service_connect_ip = local.private_service_connect_ip
  forwarding_rule_target     = "vpc-sc"
  depends_on = [
    google_project_service.servicenetworking
  ]
}

resource "google_compute_subnetwork" "swp_subnetwork_proxy" {
  name          = "sb-swp-${var.region}"
  ip_cidr_range = "10.129.0.0/23"
  project       = var.project_id
  region        = var.region
  network       = module.vpc.network_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

module "swp_firewall_rule" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  project_id   = var.project_id
  network_name = module.vpc.network_id

  rules = [{
    name        = "fw-allow-tcp-443-egress-to-secure-web-proxy"
    description = "Allow Cloud Build to connect in Secure Web Proxy"
    direction   = "EGRESS"
    priority    = 100
    ranges      = ["10.129.0.0/23", local.subnet_ip]
    source_tags = []
    allow = [{
      protocol = "tcp"
      ports    = [443]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

resource "google_compute_global_address" "private_ip_allocation" {
  name          = "swp-cloud-function-internal-connection"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = module.vpc.network_id
}

resource "time_sleep" "wait_network_config_propagation" {
  create_duration  = "1m"
  destroy_duration = "2m"

  depends_on = [
    google_service_networking_connection.private_service_connect,
    google_compute_subnetwork.swp_subnetwork_proxy
  ]
}

resource "google_network_security_gateway_security_policy" "swp_security_policy" {
  name        = "swp-security-policy"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy security policy."
}

resource "google_network_security_url_lists" "swp_url_lists" {
  name        = "swp-url-lists"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy list of allowed URLs."
  values      = [
    "*google.com/go*",
    "*github.com/GoogleCloudPlatform*",
    "*github.com/cloudevents*",
    "*golang.org/x*",
    "*google.golang.org/*",
    "*github.com/golang/*",
    "*github.com/google/*",
    "*github.com/googleapis/*",
    "*github.com/json-iterator/go",
    "*dl.google.com/*",
    "*debian.map.fastly.net/*",
    "*deb.debian.org/*",
    "*packages.cloud.google.com/*",
    "*pypi.org/*",
    "*gitlab.com/*" //gitlab IP
  ]
}

resource "google_network_security_gateway_security_policy_rule" "swp_security_policy_rule" {
  name                    = "swp-security-policy-rule"
  project                 = var.project_id
  location                = var.region
  gateway_security_policy = google_network_security_gateway_security_policy.swp_security_policy.name
  enabled                 = true
  description             = "Secure Web Proxy security policy rule."
  priority                = 1
  session_matcher         = "inUrlList(host(), '${google_network_security_url_lists.swp_url_lists.id}')"
  tls_inspection_enabled  = false
  basic_profile           = "ALLOW"

  depends_on = [
    google_network_security_url_lists.swp_url_lists,
    google_network_security_gateway_security_policy.swp_security_policy
  ]
}

resource "google_network_services_gateway" "secure_web_proxy" {
  project                              = var.project_id
  name                                 = "secure-web-proxy"
  location                             = var.region
  type                                 = "SECURE_WEB_GATEWAY"
  addresses                            = [local.proxy_ip]
  ports                                = [443]
  certificate_urls                     = ["projects/${var.project_id}/locations/${var.region}/certificates/swp-certificate"]
  gateway_security_policy              = google_network_security_gateway_security_policy.swp_security_policy.id
  network                              = module.vpc.network_id
  subnetwork                           = "projects/${var.project_id}/regions/${var.region}/subnetworks/${module.vpc.subnets_names[0]}"
  scope                                = "samplescope"
  delete_swg_autogen_router_on_destroy = true

  depends_on = [
    google_compute_subnetwork.swp_subnetwork_proxy,
    google_service_networking_connection.private_service_connect,
    google_network_security_gateway_security_policy_rule.swp_security_policy_rule
  ]
}

resource "null_resource" "generate_certificate" {
  triggers = {
    project_id = var.project_id
    region     = var.region
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
      ${path.cwd}/helpers/generate_swp_certificate.sh \
        ${var.project_id} \
        ${var.region}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      gcloud certificate-manager certificates delete swp-certificate \
        --location=${self.triggers.region} --project=${self.triggers.project_id} \
        --quiet
    EOT
  }

  depends_on = [
    module.vpc
  ]
}

resource "time_sleep" "wait_upload_certificate" {
  create_duration = "1m"

  depends_on = [
    null_resource.generate_certificate
  ]
}

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [
      "projects/342927644502",
      "projects/213358688945",
      "projects/907015832414"
    ] //google project, bank of anthos

    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "secretmanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "egress_policy" {
  count     = var.service_perimeter_mode == "DRY_RUN" ? 1 : 0
  perimeter = var.service_perimeter_name
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [
      "projects/342927644502",
      "projects/213358688945",
      "projects/907015832414"
    ] //google project, bank of anthos

    operations {
      service_name = "cloudbuild.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "secretmanager.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "time_sleep" "wait_propagation" {
  depends_on = [
    module.vpc,
    google_compute_network_peering_routes_config.peering_routes,
    google_dns_policy.default_policy,
    module.private_service_connect,
    module.firewall_rules,
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    # module.secure_web_proxy
  ]
  create_duration  = "1m"
  destroy_duration = "1m"
}

