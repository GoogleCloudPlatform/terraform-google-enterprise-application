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

output "harness_project_ids" {
  description = "A list of the projects ids created including seed."
  value       = merge({ for i, v in module.harness_project : (i) => v.project_id }, { "seed" : module.seed_project.project_id })
}

output "harness_project_numbers" {
  description = "A list of the projects numbers created including seed."
  value       = merge({ for i, v in module.harness_project : (i) => v.project_number }, { "seed" : module.seed_project.project_number })
}

output "seed_project_number" {
  description = "Seed project number."
  value       = module.seed_project.project_number
}

output "seed_project_id" {
  description = "Seed project id."
  value       = module.seed_project.project_id
}

output "ncc_group" {
  description = "The NCC group name."
  value       = "edge"
}

output "ncc_hub_uri" {
  description = "NCC Hub id."
  value       = module.network_connectivity_center_star.ncc_hub.id
}

output "seed_folder_id" {
  description = "Seed folder id."
  value       = module.folder_seed.id
}

output "sa_email" {
  description = "All service accounts email created for examples, including in seed project."
  value       = { for i, v in google_service_account.int_test : (i) => v.email }
}

output "sa_id" {
  description = "All service accounts id created for examples, including in seed project."
  value       = { for i, v in google_service_account.int_test : (i) => v.id }
}

output "sa_key" {
  description = "The seed private key."
  value       = google_service_account_key.int_test["seed"].private_key
  sensitive   = true
}

output "cloud_build_sa" {
  description = "The cloud build service account (when using Cloud build)."
  value       = var.cloud_build_sa
}

output "billing_account" {
  description = "Billing account used to be linked at projects."
  value       = var.billing_account
}

output "org_id" {
  description = "Organization ID used to create projects."
  value       = var.org_id
}

output "teams" {
  description = "Workspace groups id."
  value       = { for team, group in module.group : team => module.group[team].id }
}

output "single_project" {
  description = "If single project examples are being deployed."
  value       = var.single_project
}

output "hpc" {
  description = "If is a HPC example being deployed."
  value       = var.hpc
}
