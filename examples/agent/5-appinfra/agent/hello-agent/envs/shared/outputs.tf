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

output "clouddeploy_targets_names" {
  description = "Cloud deploy targets names."
  value       = module.app.clouddeploy_targets_names
}

output "service_repository_name" {
  description = "The Source Repository name."
  value       = module.app.service_repository_name
}

output "service_repository_project_id" {
  description = "The Source Repository project id."
  value       = module.app.service_repository_project_id
}

output "model_armor" {
  description = "Model armor template_id"
  value       = { for env, model in module.model_armor_configuration : (env) => model.template.id }
}

output "cluster_sa" {
  description = "Model armor template_id"
  value       = local.cluster_service_accounts
}
