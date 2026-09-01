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

locals {
  regions = distinct([for subnet in var.subnets : subnet.subnet_region])
}

module "cluster_vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.1"

  project_id      = var.project_id
  network_name    = "vpc-${var.vpc_name}"
  shared_vpc_host = var.shared_vpc_host

  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

  subnets          = var.subnets
  secondary_ranges = var.secondary_ranges
}

module "cluster_private_service_connect" {
  source  = "terraform-google-modules/network/google//modules/private-service-connect"
  version = "~> 18.0"
  count   = var.shared_vpc_host ? 1 : 0

  project_id                 = module.cluster_vpc.project_id
  network_self_link          = module.cluster_vpc.network_self_link
  private_service_connect_ip = var.private_service_connect_ip
  forwarding_rule_target     = "vpc-sc"
}

resource "google_compute_router" "nat_router" {
  for_each = toset(local.regions)
  name     = "${var.vpc_name}-nat-router-${each.value}"
  region   = each.value
  network  = module.cluster_vpc.network_self_link
  project  = module.cluster_vpc.project_id
}

resource "google_compute_router_nat" "cloud_nat" {
  for_each                           = google_compute_router.nat_router
  name                               = "${var.vpc_name}-cloud-nat"
  router                             = each.value.name
  region                             = each.value.region
  project                            = module.cluster_vpc.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_network_connectivity_spoke" "vpc_spoke" {
  count = var.ncc_config.enable_ncc ? 1 : 0

  project     = module.cluster_vpc.project_id
  name        = var.ncc_config.spoke_name
  location    = "global"
  description = var.ncc_config.spoke_description
  hub         = var.ncc_config.hub_uri
  labels      = var.ncc_config.spoke_labels
  group       = var.ncc_config.spoke_group

  linked_vpc_network {
    uri                   = module.cluster_vpc.network_id
    exclude_export_ranges = var.ncc_config.spoke_exclude_export_ranges
    include_export_ranges = var.ncc_config.spoke_include_export_ranges
  }
}
