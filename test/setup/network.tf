/**
 * Copyright 2025 Google LLC
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

# Create VPC networks
module "vpc" {
  for_each = !var.single_project ? module.vpc_project : module.project_standalone
  source   = "terraform-google-modules/network/google"
  version  = "~> 10.0"

  project_id      = each.value.project_id
  network_name    = "eab-vpc-${each.key}"
  shared_vpc_host = !var.single_project

  egress_rules = [
    {
      name     = "allow-private-google-access"
      priority = 200
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      destination_ranges = [
        "34.126.0.0/18",
        "199.36.153.8/30",
      ]
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name     = "allow-private-google-access-ipv6"
      priority = 200
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      destination_ranges = [
        "2600:2d00:2:2000::/64",
        "2001:4860:8040::/42"
      ]
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    }
  ]
  ingress_rules = [
    {
      name     = "allow-ssh"
      priority = 65534
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name     = "allow-internal"
      priority = 65534
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["10.128.0.0/9"]
      allow = [
        {
          protocol = "tcp"
        },
        {
          protocol = "udp"
        },
        {
          protocol = "icmp"
        }
      ]
    },

    {
      name     = "allow-icmp"
      priority = 65534
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "icmp"
        }
      ]
    }
  ]

  subnets = concat([
    {
      subnet_name           = "eab-${each.key}-us-central1"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
      }], !var.single_project ? [{
      subnet_name           = "eab-${each.key}-us-east4"
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "us-east4"
      subnet_private_access = true
  }] : [])

  secondary_ranges = merge({
    "eab-${each.key}-us-central1" = [
      {
        range_name    = "eab-${each.key}-us-central1-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-${each.key}-us-central1-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
    }, !var.single_project ? { "eab-${each.key}-us-east4" = [
      {
        range_name    = "eab-${each.key}-us-east4-secondary-01"
        ip_cidr_range = "192.168.128.0/18"
      },
      {
        range_name    = "eab-${each.key}-us-east4-secondary-02"
        ip_cidr_range = "192.168.192.0/18"
      },
  ] } : {})
}

resource "google_dns_policy" "default_policy" {
  for_each                  = module.vpc
  project                   = each.value.project_id
  name                      = "dp-b-cbpools-default-policy"
  enable_inbound_forwarding = true
  enable_logging            = true
  networks {
    network_url = each.value.network_self_link
  }
}

resource "google_project_service" "servicenetworking" {
  for_each           = module.vpc
  service            = "servicenetworking.googleapis.com"
  project            = each.value.project_id
  disable_on_destroy = false
}

resource "google_compute_global_address" "worker_range" {
  for_each      = module.vpc
  name          = "cga-worker"
  project       = each.value.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = each.value.network_id
}

resource "google_service_networking_connection" "worker_pool_conn" {
  for_each                = module.vpc
  network                 = each.value.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range[each.key].name]
  depends_on              = [google_project_service.servicenetworking]
}

module "private_service_connect" {
  for_each                   = module.vpc
  source                     = "terraform-google-modules/network/google//modules/private-service-connect"
  version                    = "~> 10.0"
  project_id                 = each.value.project_id
  network_self_link          = each.value.network_self_link
  private_service_connect_ip = "10.3.0.5"
  forwarding_rule_target     = "vpc-sc"
}


resource "google_compute_network_peering_routes_config" "peering_routes" {
  for_each             = module.vpc
  project              = each.value.project_id
  peering              = google_service_networking_connection.private_service_connect[each.key].peering
  network              = each.value.network_name
  import_custom_routes = true
  export_custom_routes = true
}

resource "google_service_networking_connection" "private_service_connect" {
  for_each                = module.vpc
  network                 = each.value.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range[each.key].name]
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  for_each     = module.vpc
  project_id   = each.value.project_id
  network_name = each.value.network_name

  rules = [{
    name                    = "fw-b-cbpools-100-i-a-all-all-all-service-networking"
    description             = "allow ingress from the IPs configured for service networking"
    direction               = "INGRESS"
    priority                = 100
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_range[each.key].address}/${google_compute_global_address.worker_range[each.key].prefix_length}"]

    allow = [{
      protocol = "all"
      ports    = null
    }]

    deny = []

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}
