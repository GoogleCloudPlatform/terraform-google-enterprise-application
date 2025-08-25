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

output "seed_project_id" {
  value = var.seed_project_id
}

output "seed_project_number" {
  value = data.google_project.seed_project.number
}

output "single_project_cluster_subnetwork_name" {
  value = module.single_project_vpc.subnets_names[0]
}

output "single_project_cluster_subnetwork_self_link" {
  value = module.single_project_vpc.subnets_self_links[0]
}

output "binary_authorization_image" {
  value = local.binary_auth_image_tag
}

output "attestation_evaluation_mode" {
  value = "REQUIRE_ATTESTATION"
}

output "binary_authorization_repository_id" {
  description = "The ID of the Repository where binary attestation image is stored."
  value       = google_artifact_registry_repository.attestation_image.id
}
