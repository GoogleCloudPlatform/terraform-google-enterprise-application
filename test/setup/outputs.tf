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
  value = merge({ for i, v in module.harness_project : (i) => v.project_id }, { "seed" : module.seed_project.project_id })
}

output "harness_project_numbers" {
  value = merge({ for i, v in module.harness_project : (i) => v.project_number }, { "seed" : module.seed_project.project_number })
}

output "seed_project_number" {
  value = module.seed_project.project_number
}

output "seed_project_id" {
  value = module.seed_project.project_id
}

output "hub_network" {
  value = module.hub_network.network
}

output "ncc_group" {
  value = "edge"
}

output "ncc_hub_uri" {
  value = module.network_connectivity_center_star.ncc_hub.id
}

output "seed_folder_id" {
  value = module.folder_seed.id
}

output "sa_email" {
  value = { for i, v in google_service_account.int_test : (i) => v.email }
}

output "sa_id" {
  value = { for i, v in google_service_account.int_test : (i) => v.id }
}

output "sa_key" {
  value     = google_service_account_key.int_test["seed"].private_key
  sensitive = true
}

output "cloud_build_sa" {
  value = var.cloud_build_sa
}

output "billing_account" {
  value = var.billing_account
}

output "org_id" {
  value = var.org_id
}

output "teams" {
  value = { for team, group in module.group : team => module.group[team].id }
}

output "single_project" {
  value = var.single_project
}

output "hpc" {
  value = var.hpc
}
