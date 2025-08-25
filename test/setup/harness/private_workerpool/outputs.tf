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

output "workerpool_project_id" {
  value = module.private_workerpool.workerpool_project_id
}

output "workerpool_project_number" {
  value = module.private_workerpool.workerpool_project_number
}

output "workerpool_network_name" {
  value = module.private_workerpool.workerpool_network_name
}

output "workerpool_network_id" {
  value = module.private_workerpool.workerpool_network_id
}

output "workerpool_id" {
  value = module.private_workerpool.workerpool_id
}

output "workerpool_network_self_link" {
  value = module.private_workerpool.workerpool_network_self_link
}

output "workerpool_subnets_self_links" {
  value = module.private_workerpool.workerpool_subnets_self_links
}
