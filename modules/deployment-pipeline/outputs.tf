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

output "clouddeploy_targets_names" {
  description = "Cloud deploy targets names."
  value       = module.cd.clouddeploy_target_names_ordered
}

output "service_repository_name" {
  description = "The Source Repository name."
  value       = var.repo_name
}

output "service_repository_project_id" {
  description = "The Source Repository project id."
  value       = var.project_id
}

output "cloudbuild_service_account" {
  description = "Service Account created to run Cloud Build."
  value       = module.ci.build_sa_email
}

output "app_artifact_repo" {
  description = "Docker artifact registry repo to store app build images."
  value       = module.ci.app_artifact_repo
}

output "cache_bucket_name" {
  description = "The name of the storage bucket for cloud build."
  value       = module.ci.cache_bucket_name
}
