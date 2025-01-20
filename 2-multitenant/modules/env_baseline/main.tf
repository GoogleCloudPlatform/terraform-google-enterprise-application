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

  subnets = { for idx, v in var.cluster_subnetworks : idx => v }

  subnets_to_cidr = {
    for idx, subnet_key in keys(data.google_compute_subnetwork.default) : subnet_key => local.available_cidr_ranges[idx]
  }

  arm_node_pool_iterator = { for k, v in module.gke-standard : k => v if v.location == "us-central1" }
}

resource "google_project_service_identity" "compute_sa" {
  provider = google-beta
  project  = local.cluster_project_id
  service  = "compute.googleapis.com"
}

// Create cluster project
module "eab_cluster_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  count = var.create_cluster_project ? 1 : 0

  name                     = "eab-gke-${var.env}"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  svpc_host_project_id     = var.network_project_id
  shared_vpc_subnets       = var.cluster_subnetworks
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

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
  version = "~> 4.0"

  project_id                           = local.cluster_project_id
  name                                 = "eab-cloud-armor"
  description                          = "EAB Cloud Armor policy"
  default_rule_action                  = "allow"
  type                                 = "CLOUD_ARMOR"
  layer_7_ddos_defense_enable          = true
  layer_7_ddos_defense_rule_visibility = "STANDARD"
  user_ip_request_headers              = []

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
  for_each  = local.subnets
  self_link = each.value
}

resource "google_project_service_identity" "gke_identity_cluster_project" {
  provider   = google-beta
  project    = local.cluster_project_id
  service    = "gkehub.googleapis.com"
  depends_on = [module.eab_cluster_project]
}

resource "google_project_service_identity" "mcsd_cluster_project" {
  provider   = google-beta
  project    = local.cluster_project_id
  service    = "multiclusterservicediscovery.googleapis.com"
  depends_on = [module.eab_cluster_project]
}

resource "google_project_iam_member" "gke_service_agent" {
  project    = local.cluster_project_id
  role       = "roles/gkehub.serviceAgent"
  member     = google_project_service_identity.gke_identity_cluster_project.member
  depends_on = [module.eab_cluster_project]
}

resource "google_project_service_identity" "fleet_meshconfig_sa" {
  provider = google-beta
  project  = local.cluster_project_id
  service  = "meshconfig.googleapis.com"
}

resource "google_project_iam_member" "servicemesh_service_agent" {
  project    = local.cluster_project_id
  role       = "roles/meshconfig.serviceAgent"
  member     = google_project_service_identity.fleet_meshconfig_sa.member
  depends_on = [module.eab_cluster_project, google_project_service_identity.fleet_meshconfig_sa]
}

resource "google_project_iam_member" "multiclusterdiscovery_service_agent" {
  project = local.cluster_project_id
  role    = "roles/multiclusterservicediscovery.serviceAgent"
  member  = google_project_service_identity.mcsd_cluster_project.member
}

module "gke-standard" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version = "~> 35.0"

  for_each               = var.cluster_type != "AUTOPILOT" ? data.google_compute_subnetwork.default : {}
  name                   = "cluster-${each.value.region}-${var.env}"
  master_ipv4_cidr_block = local.subnets_to_cidr[each.key]
  project_id             = local.cluster_project_id
  regional               = true
  region                 = each.value.region
  network_project_id     = regex(local.projects_re, each.value.id)[0]
  network                = regex(local.networks_re, each.value.network)[0]
  subnetwork             = regex(local.subnetworks_re, local.subnets[each.key])[0]
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
    module.eab_cluster_project,
    google_project_iam_member.gke_service_agent,
    google_project_iam_member.servicemesh_service_agent,
    google_project_iam_member.multiclusterdiscovery_service_agent,
    google_project_service_identity.compute_sa
  ]

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  fleet_project_grant_service_agent = true

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy

}

resource "google_container_node_pool" "arm_node_pool" {
  for_each = { for k, v in module.gke-standard : v.location == "us-central1" ? {} : k => v }

  name       = "arm-node-pool"
  cluster    = each.value.name
  location   = each.value.location
  node_count = 1

  autoscaling {
    min_node_count  = 1
    max_node_count  = 100
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = "t2a-standard-4"
    disk_size_gb    = 100
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    local_ssd_count = 0
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    preemptible     = false

    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = false
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}


module "gke-autopilot" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  version = "~> 35.0"

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
    module.eab_cluster_project,
    google_project_iam_member.gke_service_agent,
    google_project_iam_member.servicemesh_service_agent,
    google_project_iam_member.multiclusterdiscovery_service_agent,
    google_project_service_identity.compute_sa
  ]

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  fleet_project_grant_service_agent = true

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}

resource "time_sleep" "wait_service_cleanup" {
  depends_on = [module.gke-autopilot.name, module.gke-standard.name]

  destroy_duration = "300s"
}
