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

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id      = var.project_id
  network_name    = "eab-vpc-${local.env}"
  shared_vpc_host = false

  egress_rules = [
    {
      name               = "allow-private-google-access"
      priority           = 200
      destination_ranges = [module.private_service_connect.private_service_connect_ip]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
  ]

  ingress_rules = [
    {
      name     = "allow-private-to-nat-ingress"
      priority = 210
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      allow = [
        {
          protocol = "icmp"
        },
        {
          protocol = "tcp",
        },
        {
          protocol = "udp"
        },

      ]
      source_ranges = ["10.10.10.0/24"]
      target_tags   = [google_compute_router_nat.nat_external_addresses.name]
    }
  ]

  subnets = [
    {
      subnet_name           = "eab-${local.short_env}-${var.region}"
      subnet_ip             = "10.10.10.0/24"
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
}

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  project            = module.vpc.project_id
  disable_on_destroy = false
}

resource "google_compute_global_address" "worker_range" {
  name          = "cga-worker"
  project       = module.vpc.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc.network_id
}

resource "google_service_networking_connection" "worker_pool_conn" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range.name]
  depends_on              = [google_project_service.servicenetworking]
}

module "private_service_connect" {
  source                     = "terraform-google-modules/network/google//modules/private-service-connect"
  version                    = "~> 10.0"
  project_id                 = module.vpc.project_id
  network_self_link          = module.vpc.network_self_link
  private_service_connect_ip = "10.3.0.5"
  forwarding_rule_target     = "vpc-sc"
}

resource "google_compute_router" "nat_router" {
  name    = "cr-${module.vpc.network_name}-${var.region}-nat-router"
  project = var.project_id
  region  = var.region
  network = module.vpc.network_self_link

  bgp {
    asn = 64512
  }
}

resource "google_compute_address" "nat_external_addresses" {
  project = var.project_id
  name    = "ca-${module.vpc.network_name}-${var.region}"
  region  = var.region
}

resource "google_compute_router_nat" "nat_external_addresses" {
  name                               = "rn-${module.vpc.network_name}-${var.region}-egress"
  project                            = var.project_id
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_external_addresses.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    filter = "TRANSLATIONS_ONLY"
    enable = true
  }
}

resource "google_service_account" "instance_sa" {
  account_id   = "sa-proxy"
  project      = var.project_id
  display_name = "Service Account used to VM proxy machine."
}

resource "google_compute_instance" "default" {
  name         = "vm-proxy"
  machine_type = "n2-standard-2"
  project      = var.project_id
  zone         = "${var.region}-a"

  tags = [google_compute_router_nat.nat_external_addresses.name]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network    = module.vpc.network_name
    subnetwork = module.vpc.subnets_self_links[0]

    access_config {
    }
  }
  can_ip_forward = true

  metadata = {
    foo = "bar"
  }

  metadata_startup_script = <<EOT
    #! /bin/bash
    set -e
    sysctl -w net.ipv4.ip_forward=1
    IFACE=$(ip -brief link | tail -1 | awk  {'print $1'})
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
  EOT

  service_account {
    email  = google_service_account.instance_sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_route" "instance_router_1" {
  name              = "cr-${module.vpc.network_name}-${var.region}-instance-router-1"
  project           = var.project_id
  network           = module.vpc.network_self_link
  dest_range        = "0.0.0.0/1"
  next_hop_instance = google_compute_instance.default.id
  priority          = 200
}

resource "google_compute_route" "instance_router_2" {
  name              = "cr-${module.vpc.network_name}-${var.region}-instance-router-2"
  project           = var.project_id
  network           = module.vpc.network_self_link
  dest_range        = "128.0.0.0/1"
  next_hop_instance = google_compute_instance.default.id
  priority          = 200
}

resource "google_compute_route" "nat_egress_1" {
  name             = "cr-${module.vpc.network_name}-${var.region}-nat-egress-1"
  project          = var.project_id
  network          = module.vpc.network_self_link
  dest_range       = "0.0.0.0/1"
  next_hop_gateway = "default-internet-gateway"
  tags             = [google_compute_router_nat.nat_external_addresses.name]
  priority         = 100
}

resource "google_compute_route" "nat_egress_2" {
  name             = "cr-${module.vpc.network_name}-${var.region}-nat-egress-2"
  project          = var.project_id
  network          = module.vpc.network_self_link
  dest_range       = "128.0.0.0/1"
  next_hop_gateway = "default-internet-gateway"
  tags             = [google_compute_router_nat.nat_external_addresses.name]
  priority         = 100
}

resource "google_access_context_manager_service_perimeter_egress_policy" "egress_policy" {
  perimeter = var.service_perimeter_name
  egress_from {
    identity_type = "ANY_IDENTITY"
  }
  egress_to {
    resources = [
      "projects/342927644502",
      "projects/213358688945",
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
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "time_sleep" "wait_propagation" {
  depends_on = [
    module.vpc,
    module.private_service_connect,
    google_service_networking_connection.worker_pool_conn,
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    google_compute_address.nat_external_addresses,
    google_compute_router_nat.nat_external_addresses,
    google_compute_router.nat_router
  ]
  create_duration  = "5m"
  destroy_duration = "5m"
}

