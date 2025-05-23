# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_project" "environment" {
  project_id = var.project_id
}

locals {
  region_number = index(var.regions, var.region)
  network_cidrs = {
    # Each region gets a distinct /12 for pods, starting from 10.0.0.0
    pods = cidrsubnet("10.0.0.0/8", 4, local.region_number)
    # Nodes get a /16 from the second half of the 10.0.0.0/8 range (starting at 10.128.0.0)
    nodes    = cidrsubnet("10.128.0.0/9", 7, local.region_number)
    services = cidrsubnet("192.168.0.0/16", 6, local.region_number) # /22 for services
  }
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet-${var.region}"
  project       = data.google_project.environment.project_id
  ip_cidr_range = local.network_cidrs.nodes
  region        = var.region
  network       = var.vpc_id

  # Secondary ranges for GKE
  secondary_ip_range {
    range_name    = "pods-range-${var.region}"
    ip_cidr_range = local.network_cidrs.pods
  }

  secondary_ip_range {
    range_name    = "services-range-${var.region}"
    ip_cidr_range = local.network_cidrs.services
  }

  # Enable flow logs (optional but recommended)
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Create Cloud Router
resource "google_compute_router" "router" {
  name    = "gke-router-${var.region}"
  project = data.google_project.environment.project_id
  region  = var.region
  network = var.vpc_id

  bgp {
    asn = 64514 + local.region_number
  }
}

# Create NAT configuration
resource "google_compute_router_nat" "nat" {
  name                               = "gke-nat-${var.region}"
  project                            = data.google_project.environment.project_id
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
