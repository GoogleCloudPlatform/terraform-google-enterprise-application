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
  value = module.project.project_id
}

output "project_id_standalone" {
  value = module.project_standalone.project_id
}

output "sa_key" {
  value     = google_service_account_key.int_test.private_key
  sensitive = true
}

output "envs" {
  value = { for env, vpc in module.vpc : env => {
    org_id             = var.org_id
    folder_id          = module.folders.ids[env]
    billing_account    = var.billing_account
    network_project_id = vpc.project_id
    network_self_link  = vpc.network_self_link,
    subnets_self_links = vpc.subnets_self_links,
  } }
}

output "common_folder_id" {
  value = module.folder_common.ids["common"]
}

output "org_id" {
  value = var.org_id
}

output "billing_account" {
  value = var.billing_account
}

# output "teams" {
#   value = { for team, group in module.group : team => module.group[team].id }
# }
