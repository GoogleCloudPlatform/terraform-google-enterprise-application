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

output "app_admin_project_id" {
  description = "Project ID of the application admin project."
  value       = local.admin_project_id
}

output "app_infra_repository_name" {
  description = "Name of the application infrastructure repository."
  value       = local.use_csr ? google_sourcerepo_repository.app_infra_repo[0].name : local.service_repo_name
}

output "app_infra_repository_url" {
  description = "URL of the application infrastructure repository."
  value       = local.use_csr ? google_sourcerepo_repository.app_infra_repo[0].url : module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories[var.service_name].url
}

output "app_infra_private_worker_pool_id" {
  description = "Private Worker Pool id for Cloud Build."
  value       = google_cloudbuild_worker_pool.pool.id
}

output "app_cloudbuild_workspace_apply_trigger_id" {
  description = "ID of the apply cloud build trigger."
  value       = module.tf_cloudbuild_workspace.cloudbuild_apply_trigger_id
}

output "app_cloudbuild_workspace_plan_trigger_id" {
  description = "ID of the plan cloud build trigger."
  value       = module.tf_cloudbuild_workspace.cloudbuild_plan_trigger_id
}

output "app_cloudbuild_workspace_artifacts_bucket_name" {
  description = "Artifacts bucket name for the application workspace."
  value       = module.tf_cloudbuild_workspace.artifacts_bucket
}

output "app_cloudbuild_workspace_logs_bucket_name" {
  description = "Logs bucket name for the application workspace."
  value       = module.tf_cloudbuild_workspace.logs_bucket
}

output "app_cloudbuild_workspace_state_bucket_name" {
  description = "Terraform state bucket name for the application workspace."
  value       = module.tf_cloudbuild_workspace.state_bucket
}

output "app_infra_project_ids" {
  description = "Application environment projects IDs."
  value       = { for key, value in module.app_infra_project : key => value.project_id }
}
