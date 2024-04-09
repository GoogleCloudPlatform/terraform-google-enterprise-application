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

  // Skip disabling APIs for gkehub.googleapis.com
  // https://cloud.google.com/anthos/fleet-management/docs/troubleshooting#error_when_disabling_the_fleet_api
  disable_services_on_destroy = false

  activate_apis = [
    "certificatemanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "container.googleapis.com",
    "mesh.googleapis.com",
    "gkehub.googleapis.com",
    "anthos.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "trafficdirector.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "sourcerepo.googleapis.com"
  ]
}

// Create Cloud Armor policy
module "cloud_armor" {
  source  = "GoogleCloudPlatform/cloud-armor/google"
  version = "~> 2.0"

  project_id                           = module.eab_cluster_project.project_id
  name                                 = "eab-cloud-armor"
  description                          = "EAB Cloud Armor policy"
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"

  pre_configured_rules = {
    "sqli_sensitivity_level_4" = {
      action          = "deny(502)"
      priority        = 1
      target_rule_set = "sqli-v33-stable"
    }

    "xss-stable_level_2" = {
      action            = "deny(502)"
      priority          = 2
      description       = "XSS Sensitivity Level 2"
      target_rule_set   = "xss-v33-stable"
      sensitivity_level = 2
    }
  }
}

// Retrieve the subnetworks
data "google_compute_subnetwork" "default" {
  for_each  = { for value in var.cluster_subnetworks : regex(local.subnetworks_re, value)[0] => value }
  self_link = each.value
}

// Create
module "ip_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.2"

  project_id   = module.eab_cluster_project.project_id
  address_type = "EXTERNAL"
  region       = "global"
  global       = true
  names        = ["frontend-ip"]
}

// Create a GKE cluster in each subnetwork
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version = "~> 30.2"

  for_each = data.google_compute_subnetwork.default
  name     = "cluster-${each.value.region}-${var.env}"

  project_id          = module.eab_cluster_project.project_id
  regional            = true
  region              = each.value.region
  network_project_id  = regex(local.projects_re, each.value.id)[0]
  network             = regex(local.networks_re, each.value.network)[0]
  subnetwork          = each.value.name
  ip_range_pods       = each.value.secondary_ip_range[0].range_name
  ip_range_services   = each.value.secondary_ip_range[1].range_name
  release_channel     = var.release_channel
  gateway_api_channel = "CHANNEL_STANDARD"

  fleet_project = module.eab_cluster_project.project_id

  identity_namespace = "${module.eab_cluster_project.project_id}.svc.id.goog"

  monitoring_enable_managed_prometheus = true
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS", "DEPLOYMENT"]

  remove_default_node_pool = true

  enable_binary_authorization = true

  cluster_resource_labels = {
    "mesh_id" : "proj-${module.eab_cluster_project.project_number}"
  }

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
    module.eab_cluster_project
  ]

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}
