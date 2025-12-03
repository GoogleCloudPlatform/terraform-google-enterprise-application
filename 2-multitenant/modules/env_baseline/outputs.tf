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
  description = "Regions with clusters."
  value = [
    for value in data.google_compute_subnetwork.default : value.region
  ]
}

output "cluster_membership_ids" {
  description = "GKE cluster membership IDs."
  value = [
    for value in merge(module.gke-standard, module.gke-autopilot) : value.fleet_membership
  ]
}

output "cluster_zones" {
  description = "GKE cluster zones."
  value = flatten([
    for value in merge(module.gke-standard, module.gke-autopilot) : value.zones
  ])
}

output "cluster_names" {
  description = "GKE cluster names."
  value = flatten([
    for value in merge(module.gke-standard, module.gke-autopilot) : value.name
  ])
}

output "cluster_project_id" {
  description = "Cluster Project ID."
  value       = data.google_project.eab_cluster_project.project_id

  depends_on = [module.gke-standard, module.gke-autopilot]
}

output "cluster_project_number" {
  description = "Cluster Project Number."
  value       = data.google_project.eab_cluster_project.number
}

output "network_project_id" {
  description = "Network Project ID."
  value       = var.network_project_id
}

output "network_names" {
  description = "Network name."
  value       = [for subnet in data.google_compute_subnetwork.default : regex(local.networks_re, subnet.network)[0]][0]
}

# Provide for future seperate Fleet Project
output "fleet_project_id" {
  description = "Fleet Project ID."
  value       = data.google_project.eab_cluster_project.project_id
}

output "app_ip_addresses" {
  description = "App IP Addresses."
  value = {
    for k, v in var.apps : k => {
      for i in range(length(module.apps_ip_address[k].names)) : module.apps_ip_address[k].names[i] => module.apps_ip_address[k].addresses[i]
    }
  }
}

output "app_certificates" {
  description = "App Certificates."
  value = [
    for value in google_compute_managed_ssl_certificate.app_ssl_certificates : value.name
  ]
}

output "cluster_type" {
  description = "Cluster type."
  value       = var.cluster_type
}

output "cluster_service_accounts" {
  description = "The default service accounts used for nodes, if not overridden in node_pools."
  value = merge(
    { for i, value in merge(module.gke-standard, module.gke-autopilot) : "cluster_${var.env}_${i}" => value.service_account },
    { for i, value in module.eab_cluster_project : "project_${var.env}_${i}" => "${value.project_number}-compute@developer.gserviceaccount.com" }
  )
}

output "cloud_armor" {
  value       = module.cloud_armor
  description = "Cloud Armor configuration."
}
