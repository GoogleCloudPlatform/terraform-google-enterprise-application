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

output "protected_projects" {
  value = var.protected_projects
}

output "service_perimeter_name" {
  description = "Service Perimeter name."
  value       = "accessPolicies/${google_access_context_manager_access_policy.policy_org.name}/servicePerimeters/${module.regular_service_perimeter.perimeter_name}"
}

output "access_level_name" {
  description = "Access level name."
  value       = module.access_level_members.name_id
}

output "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  value       = var.service_perimeter_mode
}

output "access_context_manager_name" {
  description = "Access context manager name."
  value       = google_access_context_manager_access_policy.policy_org.name
}
