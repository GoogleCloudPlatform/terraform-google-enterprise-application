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

output "project_id" {
  description = "Project ID"
  value       = var.project_id
}

output "state_bucket" {
  description = "Bucket for storing TF state"
  value       = module.tfstate_bucket.name
}

output "artifacts_bucket" {
  description = "Bucket for storing TF plans"
  value       = { for key, value in module.tf_cloudbuild_workspace : key => value.artifacts_bucket }
}

output "logs_bucket" {
  description = "Bucket for storing TF logs"
  value       = { for key, value in module.tf_cloudbuild_workspace : key => value.logs_bucket }
}

output "source_repo_urls" {
  description = "Source repository URLs"
  value       = { for repo_id, repo in google_sourcerepo_repository.gcp_repo : repo_id => "https://source.developers.google.com/p/${var.project_id}/r/${repo.name}" }
}

output "cb_service_accounts_emails" {
  description = "Service Accounts for the Multitenant Administration Cloud Build Triggers"
  value       = local.cb_service_accounts_emails
}

output "tf_project_id" {
  description = "Google Artifact registry terraform project id."
  value       = google_artifact_registry_repository.tf_image.project
}

output "tf_repository_name" {
  description = "Name of Artifact Registry repository for Terraform image."
  value       = google_artifact_registry_repository.tf_image.name
}

output "tf_tag_version_terraform" {
  description = "Docker tag version terraform."
  value       = local.docker_tag_version_terraform
}

output "cb_private_workerpool_id" {
  description = "Private Worker Pool ID used for Cloud Build Triggers."
  value       = var.workerpool_id
}
