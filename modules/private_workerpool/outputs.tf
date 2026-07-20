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

output "workerpool_project_id" {
  value       = var.project_id
  description = "Project ID where worker pool is created."
  depends_on = [ time_sleep.wait_service_network_peering, module.nat ]
}

output "workerpool_project_number" {
  value       = data.google_project.project.number
  description = "Project number where worker pool is created."
  depends_on = [ time_sleep.wait_service_network_peering, module.nat, google_cloudbuild_worker_pool.pool ]
}

output "workerpool_id" {
  value       = google_cloudbuild_worker_pool.pool.id
  description = "Worker pool ID."
  depends_on = [ time_sleep.wait_service_network_peering, module.nat, google_cloudbuild_worker_pool.pool ]
}

output "workerpool_network_name" {
  value       = local.network_name
  description = "Peered network name."
  depends_on = [ time_sleep.wait_service_network_peering, module.nat, google_cloudbuild_worker_pool.pool ]
}

output "workerpool_network_id" {
  value       = local.network_id
  description = "Peered network ID."
  depends_on = [ time_sleep.wait_service_network_peering, module.nat, google_cloudbuild_worker_pool.pool ]
}
