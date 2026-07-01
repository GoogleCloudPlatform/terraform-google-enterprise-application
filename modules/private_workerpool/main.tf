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

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_compute_global_address" "worker_range" {
  count = var.network_id == null ? 1 : 0
  project       = local.network_project_id
  name          = "worker-pool-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.3.3.0"
  prefix_length = 24
  network       = local.network_name
}

resource "google_service_networking_connection" "gitlab_worker_pool_conn" {
  count = var.network_id == null ? 1 : 0
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

resource "google_cloudbuild_worker_pool" "pool" {
  name     = "private-cb-pool"
  project  = var.project_id
  location = var.region
  worker_config {
    disk_size_gb   = 100
    machine_type   = var.workerpool_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network          = local.network_id
    peered_network_ip_range = "/24"
  }

  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn]
}

resource "time_sleep" "wait_service_network_peering" {
  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn]

  create_duration = "30s"
}
