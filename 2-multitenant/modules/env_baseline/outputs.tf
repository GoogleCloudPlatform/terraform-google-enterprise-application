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

output "cluster_ids" {
  description = "GKE cluster IDs"
  value = [
    for value in module.gke : value.cluster_id
  ]
}

// TODO(apeabody) replace with https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/pull/1878
output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value = [
    for value in data.google_container_cluster.primary : value.fleet[0].membership
  ]
}

output "fleet_project_id" {
  description = "Project ID"
  value       = module.eab_fleet_project.project_id
}
