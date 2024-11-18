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
  value       = module.multitenant_infra.cluster_project_id
}

output "cluster_project_number" {
  description = "Cluster Project ID"
  value       = module.multitenant_infra.cluster_project_number
}

output "network_project_id" {
  description = "Network Project ID"
  value       = module.multitenant_infra.network_project_id
}

output "fleet_project_id" {
  description = "Fleet Project ID"
  value       = module.multitenant_infra.fleet_project_id
}

output "env" {
  description = "Environment"
  value       = local.env
}

output "cluster_regions" {
  description = "Regions with clusters"
  value       = module.multitenant_infra.cluster_regions
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs"
  value       = module.multitenant_infra.cluster_membership_ids
}

output "app_ip_addresses" {
  description = "App IP Addresses"
  value       = module.multitenant_infra.app_ip_addresses
}

output "app_certificates" {
  description = "App Certificates"
  value       = module.multitenant_infra.app_certificates
}

output "acronyms" {
  description = "App Acronyms"
  value       = { for k, v in local.apps : (k) => v.acronym }
}

output "cluster_type" {
  description = "Cluster type"
  value       = module.multitenant_infra.cluster_type
}

output "cluster_service_accounts" {
  description = "The default service accounts used for nodes, if not overridden in node_pools."
  value       = module.multitenant_infra.cluster_service_accounts
}

output "app_infos" {
  description = "App infos (name, services, team)."
  value       = local.cicd_apps
}

output "clouddeploy_targets_names" {
  description = "Cloud deploy targets names."
  value       = { for k, cicd in module.cicd : k => cicd.clouddeploy_targets_names }
}
