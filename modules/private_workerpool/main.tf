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

  depends_on = [
    time_sleep.wait_service_network_peering,
  ]
}
