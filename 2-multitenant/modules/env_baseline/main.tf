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

locals {
  networks_re    = "/networks/([^/]*)$"
  subnetworks_re = "/subnetworks/([^/]*)$"
  project_id_re  = "projects/([^/]*)/"
}

# Create cluster(s) project
module "eab_cluster_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name              = "eab-gke-${var.env}"
  random_project_id = "true"
  org_id            = var.org_id
  folder_id         = var.folder_id
  billing_account   = var.billing_account

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "container.googleapis.com"
  ]
}

# Create fleet project
module "eab_fleet_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name              = "eab-fleet-${var.env}"
  random_project_id = "true"
  org_id            = var.org_id
  folder_id         = var.folder_id
  billing_account   = var.billing_account

  activate_apis = [
    "gkehub.googleapis.com"
  ]
}

// Import the subnetworks
data "google_compute_subnetwork" "default" {
  for_each  = { for value in var.cluster_subnetworks : regex(local.subnetworks_re, value)[0] => value }
  self_link = each.value
}

// Create a GKE cluster in each subnetwork
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 30.0"

  for_each = data.google_compute_subnetwork.default
  name     = "cluster-${each.value.region}-${var.env}"

  project_id             = module.eab_cluster_project.project_id
  regional               = true
  region                 = each.value.region
  create_service_account = false
  service_account        = google_service_account.cluster_service_account.email
  network_project_id     = regex(local.project_id_re, each.value.id)[0]
  network                = regex(local.networks_re, each.value.network)[0]
  subnetwork             = each.value.name
  ip_range_pods          = each.value.secondary_ip_range[0].range_name
  ip_range_services      = each.value.secondary_ip_range[1].range_name
  release_channel        = var.release_channel

  monitoring_enable_managed_prometheus = true
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS", "DEPLOYMENT"]

  remove_default_node_pool = true

  node_pools = [
    {
      name            = "node-pool-1"
      strategy        = "SURGE"
      max_surge       = 1
      max_unavailable = 0
    }
  ]

  depends_on = [
    google_project_iam_member.cluster_service_account,
    google_project_iam_member.cluster_service_account_network_project
  ]

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}

// TODO(apeabody) replace with https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/pull/1878
// Enable fleet membership on the clusters
module "fleet" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/fleet-membership"
  version = "~> 30.0"

  for_each = module.gke

  project_id   = module.eab_fleet_project.project_id
  cluster_name = each.value.name
  location     = each.value.region

  # TODO: add after release https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/pull/1865
  # membership_location = each.value.region
}

// TODO(apeabody) replace with https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/pull/1878
data "google_container_cluster" "primary" {
  for_each   = module.gke
  depends_on = [module.fleet.wait]

  project  = module.eab_cluster_project.project_id
  name     = each.value.name
  location = each.value.region
}
