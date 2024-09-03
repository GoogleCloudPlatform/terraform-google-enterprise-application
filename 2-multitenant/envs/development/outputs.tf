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

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value       = module.env.cluster_membership_ids
}

output "app_ip_addresses" {
  description = "App IP Addresses"
  value       = module.env.app_ip_addresses
}

output "app_certificates" {
  description = "App Certificates"
  value       = module.env.app_certificates
}

output "cluster_type" {
  description = "Cluster type"
  value       = module.env.cluster_type
}

output "cluster_service_accounts" {
  description = "The default service accounts used for nodes, if not overridden in node_pools."
  value       = module.env.cluster_service_accounts
}
