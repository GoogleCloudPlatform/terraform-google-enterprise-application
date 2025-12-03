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
  description = "Cluster Project ID."
  value       = module.env.cluster_project_id
}

output "cluster_project_number" {
  description = "Cluster Project number."
  value       = module.env.cluster_project_number
}

output "network_project_id" {
  description = "Network Project ID."
  value       = module.env.network_project_id
}

output "network_names" {
  description = "Network Names."
  value       = module.env.network_names
}

output "fleet_project_id" {
  description = "Fleet Project ID."
  value       = module.env.fleet_project_id
}

output "env" {
  description = "Environments."
  value       = local.env
}

output "cluster_regions" {
  description = "Regions with clusters."
  value       = module.env.cluster_regions
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs."
  value       = module.env.cluster_membership_ids
}

output "cluster_names" {
  description = "GKE cluster names."
  value       = module.env.cluster_names
}

output "app_ip_addresses" {
  description = "App IP Addresses."
  value       = module.env.app_ip_addresses
}

output "app_certificates" {
  description = "App Certificates."
  value       = module.env.app_certificates
}

output "acronyms" {
  description = "App Acronyms."
  value       = { for k, v in var.apps : (k) => v.acronym }
}

output "cluster_type" {
  description = "Cluster type."
  value       = module.env.cluster_type
}

output "cluster_service_accounts" {
  description = "The default service accounts used for nodes, if not overridden in node_pools."
  value       = module.env.cluster_service_accounts
}

output "cluster_zones" {
  description = "GKE cluster zones."
  value       = module.env.cluster_zones
}
