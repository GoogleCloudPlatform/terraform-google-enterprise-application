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

output "cluster_regions" {
  description = "Regions with clusters"
  value = [
    for value in data.google_compute_subnetwork.default : value.region
  ]
}

output "cluster_ids" {
  description = "GKE cluster IDs"
  value = [
    for value in module.gke : value.cluster_id
  ]
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value = [
    for value in module.gke : value.fleet_membership
  ]
}

output "cluster_project_id" {
  description = "Cluster Project ID"
  value       = module.eab_cluster_project.project_id
}

output "network_project_id" {
  description = "Network Project ID"
  value       = var.network_project_id
}

# Provide for future seperate Fleet Project
output "fleet_project_id" {
  description = "Fleet Project ID"
  value       = module.eab_cluster_project.project_id
}

output "ip_address_self_links" {
  description = "IP Address Self Links"
  value = {
    "frontend-ip" = module.ip_address_frontend_ip.self_links[0]
  }
}

output "ip_addresses" {
  description = "IP Addresses"
  value = {
    "frontend-ip" = module.ip_address_frontend_ip.addresses[0]
  }
}

output "cloudsql_self_links" {
  description = "Cloud SQL Self Links"
  value = {
    for value in module.cloudsql : value.instance_name => value.instance_self_link
  }
}
