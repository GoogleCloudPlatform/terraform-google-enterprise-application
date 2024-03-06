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
  projects_re    = "projects/([^/]*)/"
}

// Create cluster project
module "eab_cluster_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name                 = "eab-gke-${var.env}"
  random_project_id    = "true"
  org_id               = var.org_id
  folder_id            = var.folder_id
  billing_account      = var.billing_account
  svpc_host_project_id = var.network_project_id
  shared_vpc_subnets   = var.cluster_subnetworks

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "container.googleapis.com"
  ]
}

// Create fleet project
module "eab_fleet_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name              = "eab-fleet-${var.env}"
  random_project_id = "true"
  org_id            = var.org_id
  folder_id         = var.folder_id
  billing_account   = var.billing_account

  // Skip disabling APIs for gkehub.googleapis.com
  // https://cloud.google.com/anthos/fleet-management/docs/troubleshooting#error_when_disabling_the_fleet_api
  disable_services_on_destroy = false

  activate_apis = [
    "gkehub.googleapis.com",
    "anthos.googleapis.com",
    "compute.googleapis.com",
    "mesh.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com"
  ]
}

// Retrieve the subnetworks
data "google_compute_subnetwork" "default" {
  for_each  = { for value in var.cluster_subnetworks : regex(local.subnetworks_re, value)[0] => value }
  self_link = each.value
}

// Create a GKE cluster in each subnetwork
module "gke" {

  // TODO(apeabody) replace when beta-private-cluster ~> 30.2 released
  // source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  // version = "~> 30.1"
  source = "github.com/terraform-google-modules/terraform-google-kubernetes-engine//modules/beta-private-cluster?ref=dd291dac521beba4a862a3bb68a873ca2e1cfa20"

  for_each = data.google_compute_subnetwork.default
  name     = "cluster-${each.value.region}-${var.env}"

  project_id         = module.eab_cluster_project.project_id
  regional           = true
  region             = each.value.region
  network_project_id = regex(local.projects_re, each.value.id)[0]
  network            = regex(local.networks_re, each.value.network)[0]
  subnetwork         = each.value.name
  ip_range_pods      = each.value.secondary_ip_range[0].range_name
  ip_range_services  = each.value.secondary_ip_range[1].range_name
  release_channel    = var.release_channel
  fleet_project      = module.eab_fleet_project.project_id

  monitoring_enable_managed_prometheus = true
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS", "DEPLOYMENT"]

  remove_default_node_pool = true

  enable_binary_authorization = true

  node_pools = [
    {
      name            = "node-pool-1"
      strategy        = "SURGE"
      max_surge       = 1
      max_unavailable = 0
      autoscaling     = true
      location_policy = "BALANCED"
    }
  ]

  depends_on = [
    module.eab_cluster_project,
    module.eab_fleet_project
  ]

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}
