# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

output "clouddeploy_targets_names" {
  description = "Cloud deploy targets names."
  value       = [for target in google_clouddeploy_target.clouddeploy_targets : target.name]
}

output "service_repository_name" {
  description = "The Source Repository name."
  value       = local.use_csr ? google_sourcerepo_repository.app_repo[0].name : local.service_repo_name
}

output "service_repository_project_id" {
  description = "The Source Repository project id."
  value       = local.use_csr ? google_sourcerepo_repository.app_repo[0].project : var.project_id
}

output "cloudbuild_service_account" {
  description = "Service Account created to run Cloud Build."
  value       = google_service_account.cloud_build.email
}
