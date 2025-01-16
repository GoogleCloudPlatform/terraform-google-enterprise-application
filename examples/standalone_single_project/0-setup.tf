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
      name     = "allow-private-google-access"
      priority = 200
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
      destination_ranges = [
        "2600:2d00:0002:2000::/64",
        "2001:4860:8040::/42"
      ]
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name     = "fw-e-shared-restricted-65534-e-a-allow-google-apis-all-tcp-443"
      priority = 65534

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      deny = []
      allow = [{
        protocol = "tcp"
        ports    = ["443"]
      }]

      ranges      = ["10.3.0.5"]
      target_tags = ["allow-google-apis", "vpc-connector"]
    }
  ]

  subnets = [
    {
      subnet_name           = "eab-${local.short_env}-region01"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    },
    {
      subnet_name           = "eab-${local.short_env}-region02"
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "us-east4"
      subnet_private_access = true
    },
  ]

  secondary_ranges = {
    "eab-${local.short_env}-region01" = [
      {
        range_name    = "eab-${local.short_env}-region01-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-${local.short_env}-region01-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]

    "eab-${local.short_env}-region02" = [
      {
        range_name    = "eab-${local.short_env}-region02-secondary-01"
        ip_cidr_range = "192.168.128.0/18"
      },
      {
        range_name    = "eab-${local.short_env}-region02-secondary-02"
        ip_cidr_range = "192.168.192.0/18"
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
resource "time_sleep" "wait_propagation" {
  depends_on       = [module.private_service_connect, google_service_networking_connection.worker_pool_conn]
  create_duration  = "1m"
  destroy_duration = "1m"
}
