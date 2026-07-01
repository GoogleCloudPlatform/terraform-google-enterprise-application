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

output "binary_authz_image_project_id" {
  description = "Google Artifact registry terraform project id."
  value       = google_artifact_registry_repository.attestation_image.project
}

output "binary_authz_image__repository_name" {
  description = "Name of Artifact Registry repository for Binaru Authz image."
  value       = google_artifact_registry_repository.attestation_image.name
}

output "binary_authorization_repository_id" {
  description = "The ID of the Repository where binary attestation image is stored."
  value       = google_artifact_registry_repository.attestation_image.id
}

output "binary_authorization_image" {
  description = "Image tag to create attestations."
  value       = local.binary_auth_image_tag
}
