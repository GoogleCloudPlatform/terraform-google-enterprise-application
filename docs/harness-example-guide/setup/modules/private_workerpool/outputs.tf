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
  value       = module.private_workerpool_project.project_id
  description = "The ID of the project where the worker pool is located."
}

output "workerpool_id" {
  value       = google_cloudbuild_worker_pool.pool.id
  description = "The ID of the Cloud Build worker pool."
}

output "workerpool_project_number" {
  value       = module.private_workerpool_project.project_number
  description = "The number of the project where the worker pool is located."
}

output "workerpool_network_name" {
  value       = module.vpc.network_name
  description = "The name of the VPC network for the worker pool."
}

output "workerpool_network_id" {
  value       = module.vpc.network_id
  description = "The ID of the VPC network for the worker pool."
}

output "workerpool_network_self_link" {
  value       = module.vpc.network_self_link
  description = "The self-link of the VPC network for the worker pool."
}

output "workerpool_subnets_self_links" {
  value       = module.vpc.subnets_self_links
  description = "The self-links of the subnets for the worker pool."
}
