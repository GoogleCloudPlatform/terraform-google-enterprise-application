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
  networks_re           = "/networks/([^/]*)$"
  subnetworks_re        = "/subnetworks/([^/]*)$"
  projects_re           = "projects/([^/]*)/"
  cluster_project_id    = data.google_project.eab_cluster_project.project_id
  available_cidr_ranges = var.master_ipv4_cidr_blocks

  subnets_to_cidr = {
    for idx, subnet_key in keys(data.google_compute_subnetwork.default) : subnet_key => local.available_cidr_ranges[idx]
  }
}

// Create cluster project
module "eab_cluster_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 16.0"

  count = var.create_cluster_project ? 1 : 0

  name                     = "eab-gke-${var.env}"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  svpc_host_project_id     = var.network_project_id
  shared_vpc_subnets       = var.cluster_subnetworks

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
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudtrace.googleapis.com"
  ]
}

data "google_project" "eab_cluster_project" {
  project_id = var.create_cluster_project ? module.eab_cluster_project[0].project_id : var.network_project_id
}

// Create Cloud Armor policy
module "cloud_armor" {
  source  = "GoogleCloudPlatform/cloud-armor/google"
  version = "~> 3.0"

  project_id                           = local.cluster_project_id
  name                                 = "eab-cloud-armor"
  description                          = "EAB Cloud Armor policy"
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"

  pre_configured_rules = {
    "sqli_sensitivity_level_1" = {
      action            = "deny(502)"
      priority          = 1
      target_rule_set   = "sqli-v33-stable"
      sensitivity_level = 1
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

module "gke-standard" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version = "~> 33.0"

  for_each               = var.cluster_type != "AUTOPILOT" ? data.google_compute_subnetwork.default : {}
  name                   = "cluster-${each.value.region}-${var.env}"
  master_ipv4_cidr_block = local.subnets_to_cidr[each.key]
  project_id             = local.cluster_project_id
  regional               = true
  region                 = each.value.region
  network_project_id     = regex(local.projects_re, each.value.id)[0]
  network                = regex(local.networks_re, each.value.network)[0]
  subnetwork             = each.value.name
  ip_range_pods          = each.value.secondary_ip_range[0].range_name
  ip_range_services      = each.value.secondary_ip_range[1].range_name
  release_channel        = var.cluster_release_channel
  gateway_api_channel    = "CHANNEL_STANDARD"

  security_posture_vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  datapath_provider                   = "ADVANCED_DATAPATH"
  enable_cost_allocation              = true

  fleet_project = local.cluster_project_id

  identity_namespace = "${local.cluster_project_id}.svc.id.goog"

  monitoring_enable_managed_prometheus = true
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS", "DEPLOYMENT"]

  remove_default_node_pool = true
  cluster_autoscaling = {
    enabled             = var.cluster_type == "STANDARD-NAP" ? true : false
    autoscaling_profile = "BALANCED"
    max_cpu_cores       = 100
    min_cpu_cores       = 0
    max_memory_gb       = 1024
    min_memory_gb       = 0
    gpu_resources = [
      {
        resource_type = "nvidia-tesla-t4"
        minimum       = 0
        maximum       = 4
      }
    ]
    auto_repair  = true
    auto_upgrade = true
  }

  enable_binary_authorization = true

  cluster_resource_labels = {
    "mesh_id" : "proj-${data.google_project.eab_cluster_project.number}"
  }

  node_pools = [
    {
      name            = "node-pool-1"
      machine_type    = "e2-standard-4"
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

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}

module "gke-autopilot" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  version = "~> 33.0"

  for_each = var.cluster_type == "AUTOPILOT" ? data.google_compute_subnetwork.default : {}
  name     = "cluster-${each.value.region}-${var.env}"

  project_id          = local.cluster_project_id
  regional            = true
  region              = each.value.region
  network_project_id  = regex(local.projects_re, each.value.id)[0]
  network             = regex(local.networks_re, each.value.network)[0]
  subnetwork          = each.value.name
  ip_range_pods       = each.value.secondary_ip_range[0].range_name
  ip_range_services   = each.value.secondary_ip_range[1].range_name
  release_channel     = var.cluster_release_channel
  gateway_api_channel = "CHANNEL_STANDARD"
  enable_gcfs         = true

  security_posture_vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  enable_cost_allocation              = true

  fleet_project = local.cluster_project_id

  identity_namespace = "${local.cluster_project_id}.svc.id.goog"

  enable_binary_authorization = true

  cluster_resource_labels = {
    "mesh_id" : "proj-${data.google_project.eab_cluster_project.number}"
  }

  depends_on = [
    module.eab_cluster_project
  ]

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}
