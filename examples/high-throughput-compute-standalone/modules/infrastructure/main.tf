# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  # If storage_locations is empty, use regions from var.regions
  # Otherwise use the specified locations
  storage_locations_map = length(var.storage_locations) > 0 ? var.storage_locations : {
    for region in var.regions : region => region
  }
  ip_cidr_parts = split("/", var.storage_ip_range)
  ip_address    = local.ip_cidr_parts[0]
  prefix_length = local.ip_cidr_parts[1]
}

# Retrieve Google Cloud project information
data "google_project" "environment" {
  project_id = var.project_id
}

# Module to manage project-level settings and API enablement
module "project" {
  source               = "../project"
  project_id           = data.google_project.environment.project_id
  enable_log_analytics = var.enable_log_analytics
}

# Module to create VPC network and subnets
resource "google_compute_network" "research-vpc" {
  name                    = var.vpc_name
  project                 = data.google_project.environment.project_id
  auto_create_subnetworks = false
  mtu                     = var.vpc_mtu
  # enable_ula_internal_ipv6 = true
}

module "networking" {
  for_each   = toset(var.regions)
  region     = each.key
  regions    = var.regions
  source     = "../network"
  project_id = data.google_project.environment.project_id
  depends_on = [module.project]
  vpc_id     = google_compute_network.research-vpc.id
  vpc_name   = google_compute_network.research-vpc.name

}

# Conditionally create a GKE Standard cluster
module "gke_standard" {
  source = "../gke-standard"
  for_each = {
    for entry in flatten([
      for region, count in var.clusters_per_region : [
        for index in range(count) : {
          key           = "${region}-${index}"
          region        = region
          cluster_index = index
        }
      ]
    ]) : entry.key => entry
  }
  cluster_index              = each.value.cluster_index
  cluster_name               = "${var.gke_standard_cluster_name}-${each.value.region}-${each.value.cluster_index}"
  project_id                 = data.google_project.environment.project_id
  region                     = each.value.region
  # zones                      = var.zones
  network                    = google_compute_network.research-vpc.id
  subnet                     = module.networking[each.value.region].subnet_id
  ip_range_services          = module.networking[each.value.region].service_range_name
  ip_range_pods              = module.networking[each.value.region].pod_range_name
  depends_on                 = [google_service_account.cluster_service_account, module.project, module.networking]
  scaled_control_plane       = var.scaled_control_plane
  # artifact_registry          = module.artifact_registry.artifact_registry
  cluster_max_cpus           = var.cluster_max_cpus
  cluster_max_memory         = var.cluster_max_memory
  cluster_service_account    = google_service_account.cluster_service_account
  enable_csi_filestore       = var.enable_csi_filestore
  enable_csi_gcs_fuse        = var.enable_csi_gcs_fuse
  enable_csi_parallelstore   = var.enable_csi_parallelstore
  node_machine_type_ondemand = var.node_machine_type_ondemand
  node_machine_type_spot     = var.node_machine_type_spot
  min_nodes_ondemand         = var.min_nodes_ondemand
  max_nodes_ondemand         = var.max_nodes_ondemand
  min_nodes_spot             = var.min_nodes_spot
  max_nodes_spot             = var.max_nodes_spot
  release_channel            = var.release_channel
  enable_shielded_nodes      = var.enable_shielded_nodes
  enable_secure_boot         = var.enable_secure_boot
  enable_workload_identity   = var.enable_workload_identity
  enable_private_endpoint    = var.enable_private_endpoints
  create_ondemand_nodepool   = var.create_ondemand_nodepool
  create_spot_nodepool       = var.create_spot_nodepool
  datapath_provider          = var.datapath_provider
  maintenance_start_time     = var.maintenance_start_time
  maintenance_end_time       = var.maintenance_end_time
  maintenance_recurrence     = var.maintenance_recurrence
  enable_mesh_certificates   = var.enable_mesh_certificates
}

# --- Filesystem Storage ---
# --- Parallelstore Module Instance(s) ---
# This block will only create resources if var.storage_type is "PARALLELSTORE"
module "parallelstore" {
  for_each = var.storage_type == "PARALLELSTORE" ? local.storage_locations_map : {}

  source          = "../parallelstore"
  project_id      = data.google_project.environment.project_id
  location        = each.value
  network         = google_compute_network.research-vpc.id
  capacity_gib    = var.storage_capacity_gib
  deployment_type = var.parallelstore_deployment_type

  depends_on = [
    google_compute_network.research-vpc,
    google_service_networking_connection.default,
  ]
}

# --- Lustre Module Instance(s) ---
# This block will only create resources if var.storage_type is "LUSTRE"
module "lustre" {
  for_each = var.storage_type == "LUSTRE" ? local.storage_locations_map : {}

  source              = "../lustre"
  project_id          = data.google_project.environment.project_id
  location            = each.value
  network             = google_compute_network.research-vpc.id
  capacity_gib        = var.storage_capacity_gib
  filesystem          = var.lustre_filesystem
  gke_support_enabled = var.lustre_gke_support_enabled


  depends_on = [
    google_compute_network.research-vpc,
    google_service_networking_connection.default,
  ]
}

# Artifact Registry for Images
module "artifact_registry" {
  source             = "../artifact-registry"
  regions            = var.regions
  project_id         = data.google_project.environment.project_id
  name               = var.artifact_registry_name
  cleanup_keep_count = var.artifact_registry_cleanup_policy_keep_count
}

# GKE IAM
# Service Account for clusters
resource "google_service_account" "cluster_service_account" {
  account_id   = var.cluster_service_account
  display_name = var.cluster_service_account
  project      = data.google_project.environment.project_id
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = data.google_project.environment.project_id
  role    = "roles/container.serviceAgent"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "additional_roles" {
  for_each = toset(var.additional_service_account_roles)
  project  = data.google_project.environment.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_artifact_registry_repository_iam_member" "artifactregistry_reader" {
  project    = data.google_project.environment.project_id
  location   = module.artifact_registry.artifact_registry.location
  repository = module.artifact_registry.artifact_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

# Storage Networking
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.research-vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.storage_range.name]
}

resource "google_compute_global_address" "storage_range" {
  project       = data.google_project.environment.project_id
  name          = "${var.vpc_name}-storage-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = local.prefix_length
  network       = google_compute_network.research-vpc.id
  address       = local.ip_address
}
