# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



module "vpc" {
  count   = var.create_admin_project ? 1 : 0
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id      = module.app_admin_project[0].project_id
  network_name    = "eab-vpc-${var.service_name}"
  shared_vpc_host = false

  egress_rules = [
    {
      name     = "allow-private-google-access"
      priority = 200
      destination_ranges = [
        "34.126.0.0/18",
        "199.36.153.8/30",
      ]
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
    {
      name     = "allow-private-google-access-ipv6"
      priority = 200
      destination_ranges = [
        "2600:2d00:0002:2000::/64",
        "2001:4860:8040::/42"
      ]
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

  subnets = [
    {
      subnet_name           = "eab-${var.service_name}-${var.trigger_location}"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = var.trigger_location
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    "eab-${var.service_name}-${var.trigger_location}" = [
      {
        range_name    = "eab${var.service_name}-${var.trigger_location}-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab${var.service_name}-${var.trigger_location}-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }
}

resource "google_project_service" "servicenetworking" {
  count              = var.create_admin_project ? 1 : 0
  service            = "servicenetworking.googleapis.com"
  project            = module.app_admin_project[0].project_id
  disable_on_destroy = false
}

resource "google_compute_global_address" "worker_range" {
  count         = var.create_admin_project ? 1 : 0
  name          = "cga-worker"
  project       = module.app_admin_project[0].project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc[0].network_id
}

resource "google_service_networking_connection" "worker_pool_conn" {
  count                   = var.create_admin_project ? 1 : 0
  network                 = module.vpc[0].network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range[0].name]
  depends_on              = [google_project_service.servicenetworking]
}

module "private_service_connect" {
  count                      = var.create_admin_project ? 1 : 0
  source                     = "terraform-google-modules/network/google//modules/private-service-connect"
  version                    = "~> 10.0"
  project_id                 = module.app_admin_project[0].project_id
  network_self_link          = module.vpc[0].network_self_link
  private_service_connect_ip = "10.3.0.5"
  forwarding_rule_target     = "vpc-sc"
}

resource "google_compute_router" "nat_router" {
  count   = var.create_admin_project ? 1 : 0
  name    = "cr-${module.vpc[0].network_name}-${var.trigger_location}-nat-router"
  project = module.app_admin_project[0].project_id
  region  = var.trigger_location
  network = module.vpc[0].network_self_link

  bgp {
    asn = 64512
  }
}

resource "google_compute_address" "nat_external_addresses" {
  count   = var.create_admin_project ? 1 : 0
  project = module.app_admin_project[0].project_id
  name    = "ca-${module.vpc[0].network_name}-${var.trigger_location}"
  region  = var.trigger_location
}

resource "google_compute_router_nat" "nat_external_addresses" {
  count                              = var.create_admin_project ? 1 : 0
  name                               = "rn-${module.vpc[0].network_name}-${var.trigger_location}-egress"
  project                            = module.app_admin_project[0].project_id
  router                             = google_compute_router.nat_router[0].name
  region                             = var.trigger_location
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.nat_external_addresses[*].self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    filter = "TRANSLATIONS_ONLY"
    enable = true
  }
}

resource "google_compute_instance" "default" {
  count        = var.create_admin_project ? 1 : 0
  name         = "vm-proxy"
  machine_type = "n2-standard-2"
  project      = module.app_admin_project[0].project_id
  zone         = var.trigger_location

  tags = [google_compute_router_nat.nat_external_addresses[0].name]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = module.vpc[0].network_name

    access_config {
      // Ephemeral public IP
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
}

resource "google_compute_route" "instance_router_1" {
  count             = var.create_admin_project ? 1 : 0
  name              = "cr-${module.vpc[0].network_name}-${var.trigger_location}-instance-router-1"
  project           = module.app_admin_project[0].project_id
  network           = module.vpc[0].network_self_link
  dest_range        = "0.0.0.0/1"
  next_hop_instance = google_compute_instance.default[0].id
}

resource "google_compute_route" "instance_router_2" {
  count             = var.create_admin_project ? 1 : 0
  name              = "cr-${module.vpc[0].network_name}-${var.trigger_location}-instance-router-2"
  project           = module.app_admin_project[0].project_id
  network           = module.vpc[0].network_self_link
  dest_range        = "128.0.0.0/1"
  next_hop_instance = google_compute_instance.default[0].id
}
