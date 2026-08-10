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

output "workerpool_id" {
  description = "The Cloud Build Worker Pool ID."
  value       = local.workerpool_id
}

output "workerpool_project_id" {
  description = "The Cloud Build Worker Pool Project ID."
  value       = local.workerpool_project_id
}

output "workerpool_network_project_id" {
  description = "The network project ID for the workerpool."
  value       = local.workerpool_network_project_id
}

output "subnets_self_links" {
  description = "Self links of the created subnets."
  value       = module.cluster_network.subnets_self_links
}

output "binary_authorization_image" {
  description = "Binary Authorization attestor image."
  value       = module.binary_autz.binary_authorization_image
}

output "binary_authorization_repository_id" {
  description = "Binary Authorization repository ID."
  value       = module.binary_autz.binary_authorization_repository_id
}

output "required_services" {
  description = "The required Google project service resources."
  value       = google_project_service.required_services
}
