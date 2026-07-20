/**
 * Copyright 2026 Google LLC
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

resource "google_compute_global_address" "worker_range" {
  count         = var.enables_network_connection_and_peering_routes ? 1 : 0
  project       = local.network_project_id
  name          = "worker-pool-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.3.3.0"
  prefix_length = 24
  network       = local.network_name
}

resource "google_service_networking_connection" "servicenetworking_conn" {
  count                   = var.enables_network_connection_and_peering_routes ? 1 : 0
  network                 = local.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range[0].name]
  depends_on              = [google_project_service.servicenetworking]
}

resource "google_project_service" "servicenetworking" {
  project            = local.network_project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  count                = var.enables_network_connection_and_peering_routes ? 1 : 0
  project              = local.network_project_id
  peering              = google_service_networking_connection.servicenetworking_conn[0].peering
  network              = local.network_name
  import_custom_routes = true
  export_custom_routes = true
  // explicitly allow the peering for public ip address
  import_subnet_routes_with_public_ip = true
  export_subnet_routes_with_public_ip = true
}

resource "time_sleep" "wait_service_network_peering" {
  depends_on = [
    google_service_networking_connection.servicenetworking_conn,
    google_compute_network_peering_routes_config.peering_routes
  ]

  create_duration = "60s"
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 18.0"

  count = var.enables_network_connection_and_peering_routes ? 1 : 0

  project_id   = local.network_project_id
  network_name = local.network_name

  rules = [{
    name                    = "allow-pool-to-nat"
    direction               = "INGRESS"
    priority                = 1000
    source_tags             = null
    source_service_accounts = null
    target_tags             = ["nat-gateway"]
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_range[0].address}/${google_compute_global_address.worker_range[0].prefix_length}"]

    allow = [{
      protocol = "all"
      ports    = null
    }]

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    }
  ]
}
