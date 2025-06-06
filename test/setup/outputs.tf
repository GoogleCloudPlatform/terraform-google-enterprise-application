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
  value = local.project_id
}

output "project_number" {
  value = local.project_number
}

output "folder_id" {
  value = module.folder_seed.id
}

output "sa_email" {
  value = google_service_account.int_test[local.index].email
}

output "sa_key" {
  value     = google_service_account_key.int_test.private_key
  sensitive = true
}

output "envs" {
  value = var.single_project ? {} : { for env, vpc in module.cluster_vpc : env => {
    org_id             = var.org_id
    folder_id          = module.folders[local.index].ids[env]
    billing_account    = var.billing_account
    network_project_id = vpc.project_id
    network_self_link  = vpc.network_self_link,
    subnets_self_links = vpc.subnets_self_links,
  } }
}

output "workerpool_network_name" {
  value = module.vpc.network_name
}

output "workerpool_network_id" {
  value = module.vpc.network_id
}

output "workerpool_network_project_id" {
  value = module.vpc.project_id
}

output "workerpool_network_self_link" {
  value = module.vpc.network_self_link
}

output "single_project_cluster_subnetwork_name" {
  value = var.single_project ? module.single_project_vpc[0].subnets_names[0] : null
}

output "single_project_cluster_subnetwork_self_link" {
  value = var.single_project ? module.single_project_vpc[0].subnets_self_links[0] : null
}

output "network_project_number" {
  value = [for value in module.vpc_project : value.project_number]
}

output "network_project_id" {
  value = [for value in module.vpc_project : value.project_id]
}

output "common_folder_id" {
  value = try([for value in module.folder_common : value.ids["common"]][0], "")
}

output "org_id" {
  value = var.org_id
}

output "billing_account" {
  value = var.billing_account
}

output "teams" {
  value = { for team, group in module.group : team => module.group[team].id }
}

output "single_project" {
  value = var.single_project
}

output "logging_bucket" {
  value = module.logging_bucket.name
}

output "bucket_kms_key" {
  value = module.kms.keys["bucket"]
}

output "attestation_kms_key" {
  value = module.kms.keys["attestation"]
}

output "kms_keyring" {
  value = module.kms.keyring
}
