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

output "cluster_project_id" {
  description = "Cluster Project ID"
  value       = module.env.cluster_project_id
}

output "network_project_id" {
  description = "Network Project ID"
  value       = module.env.network_project_id
}

output "fleet_project_id" {
  description = "Fleet Project ID"
  value       = module.env.fleet_project_id
}

output "env" {
  description = "Environment"
  value       = local.env
}

output "cluster_regions" {
  description = "Regions with clusters"
  value       = module.env.cluster_regions
}

output "clusters_ids" {
  description = "GKE cluster IDs"
  value       = module.env.cluster_ids
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value       = module.env.cluster_membership_ids
}

output "ip_address_self_links" {
  description = "IP Address Self Links"
  value       = module.env.ip_address_self_links
}

output "ip_addresses" {
  description = "IP Addresses"
  value       = module.env.ip_addresses
}

output "cloudsql_self_links" {
  description = "Cloud SQL Self Links"
  value       = module.env.cloudsql_self_links
}
