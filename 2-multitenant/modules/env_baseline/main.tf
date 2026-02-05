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
  regions_re            = "regions/([^/]+)"
  cluster_project_id    = data.google_project.eab_cluster_project.project_id
  available_cidr_ranges = var.master_ipv4_cidr_blocks

  subnets = { for idx, v in var.cluster_subnetworks : idx => v }

  subnets_to_cidr = {
    for idx, subnet_key in keys(data.google_compute_subnetwork.default) : subnet_key => local.available_cidr_ranges[idx]
  }

  cluster_sa = [for i in merge(module.gke-standard, module.gke-autopilot) : i.service_account][0]

  arm_node_pool = { for k, v in local.subnets : k => (regex(local.regions_re, v)[0]) == "us-central1" ?
    [
      {
        name            = "regional-arm64-pool"
        machine_type    = "t2a-standard-4"
        node_locations  = "us-central1-a,us-central1-b,us-central1-f"
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 0
        autoscaling     = true
        location_policy = "BALANCED"
        sandbox_enabled = true
      }
    ] : []
  }
}

resource "google_project_service_identity" "compute_sa" {
  provider = google-beta
  project  = local.cluster_project_id
  service  = "compute.googleapis.com"
}

data "google_compute_default_service_account" "compute_sa" {
  project = local.cluster_project_id

  depends_on = [google_project_service_identity.compute_sa]
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

  vpc_service_control_attach_dry_run = var.service_perimeter_name != null
  vpc_service_control_attach_enabled = var.service_perimeter_name != null && var.service_perimeter_mode == "ENFORCE"
  vpc_service_control_perimeter_name = var.service_perimeter_name
  vpc_service_control_sleep_duration = "2m"

  // Skip disabling APIs for gkehub.googleapis.com
  // https://cloud.google.com/anthos/fleet-management/docs/troubleshooting#error_when_disabling_the_fleet_api
  disable_services_on_destroy = false

  activate_apis = [
    "aiplatform.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "anthospolicycontroller.googleapis.com",
    "binaryauthorization.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
    "mesh.googleapis.com",
    "modelarmor.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "networkmanagement.googleapis.com",
    "networkservices.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "trafficdirector.googleapis.com",
  ]

  activate_api_identities = [
    {
      api   = "networkservices.googleapis.com",
      roles = []
    },
    {
      api   = "aiplatform.googleapis.com",
      roles = ["roles/aiplatform.serviceAgent"]
    }
  ]
}

data "google_project" "eab_cluster_project" {
  project_id = var.create_cluster_project ? module.eab_cluster_project[0].project_id : var.network_project_id
}

// Create Cloud Armor policy
module "cloud_armor" {
  source  = "GoogleCloudPlatform/cloud-armor/google"
  version = "~> 5.0"

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

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members = distinct([
    data.google_compute_default_service_account.compute_sa.member,
    "serviceAccount:service-${data.google_project.eab_cluster_project.number}@container-engine-robot.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.eab_cluster_project.number}@gcp-sa-dep.iam.gserviceaccount.com",        //model armor api call
    "serviceAccount:service-${data.google_project.eab_cluster_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com", // aiplatform api call
  ])
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

resource "google_project_iam_member" "artifactregistry_reader" {
  for_each = {
    "compute_sa" : data.google_compute_default_service_account.compute_sa.member,
    "cluster_sa" : "serviceAccount:${local.cluster_sa}",
  }
  project = local.cluster_project_id
  role    = "roles/artifactregistry.reader"
  member  = each.value
}



resource "google_project_service_identity" "network_services_sa" {
  provider = google-beta
  project  = data.google_project.eab_cluster_project.project_id
  service  = "networkservices.googleapis.com"
}

resource "google_project_iam_member" "model_armor_service_network_extension_roles" {
  for_each   = toset(["roles/modelarmor.calloutUser", "roles/serviceusage.serviceUsageConsumer", "roles/modelarmor.user"])
  project    = data.google_project.eab_cluster_project.project_id
  role       = each.value
  member     = "serviceAccount:service-${data.google_project.eab_cluster_project.number}@gcp-sa-dep.iam.gserviceaccount.com"
  depends_on = [google_project_service_identity.network_services_sa]
}

module "gke-standard" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster"
  version = "~> 36.0"

  for_each               = var.cluster_type != "AUTOPILOT" ? local.subnets : {}
  name                   = "cluster-${data.google_compute_subnetwork.default[each.key].region}-${var.env}"
  master_ipv4_cidr_block = local.subnets_to_cidr[each.key]
  project_id             = local.cluster_project_id
  regional               = true
  region                 = data.google_compute_subnetwork.default[each.key].region
  network_project_id     = regex(local.projects_re, data.google_compute_subnetwork.default[each.key].id)[0]
  network                = regex(local.networks_re, data.google_compute_subnetwork.default[each.key].network)[0]
  subnetwork             = regex(local.subnetworks_re, local.subnets[each.key])[0]
  ip_range_pods          = data.google_compute_subnetwork.default[each.key].secondary_ip_range[0].range_name
  ip_range_services      = data.google_compute_subnetwork.default[each.key].secondary_ip_range[1].range_name
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

  node_pools = concat(
    [
      {
        name            = "node-pool-1"
        machine_type    = "e2-standard-4"
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 0
        autoscaling     = true
        location_policy = "BALANCED"
      }
  ], local.arm_node_pool[each.key])

  depends_on = [
    module.eab_cluster_project,
    google_project_iam_member.gke_service_agent,
    google_project_iam_member.servicemesh_service_agent,
    google_project_iam_member.multiclusterdiscovery_service_agent,
    data.google_compute_default_service_account.compute_sa,
  ]

  gcs_fuse_csi_driver = var.enable_csi_gcs_fuse

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  enable_confidential_nodes = var.enable_confidential_nodes

  fleet_project_grant_service_agent = true

  deletion_protection = var.deletion_protection

}

module "gke-autopilot" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  version = "~> 36.0"

  for_each = var.cluster_type == "AUTOPILOT" ? data.google_compute_subnetwork.default : {}
  name     = "cluster-${each.value.region}-${var.env}"

  project_id          = local.cluster_project_id
  regional            = true
  region              = each.value.region
  network_project_id  = regex(local.projects_re, each.value.id)[0]
  network             = regex(local.networks_re, each.value.network)[0]
  subnetwork          = regex(local.subnetworks_re, local.subnets[each.key])[0]
  ip_range_pods       = each.value.secondary_ip_range[0].range_name
  ip_range_services   = each.value.secondary_ip_range[1].range_name
  release_channel     = var.cluster_release_channel
  gateway_api_channel = "CHANNEL_STANDARD"


  security_posture_vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  enable_cost_allocation              = true

  fleet_project = local.cluster_project_id

  identity_namespace = "${local.cluster_project_id}.svc.id.goog"

  enable_binary_authorization = true

  cluster_resource_labels = {
    "mesh_id" : "proj-${data.google_project.eab_cluster_project.number}"
  }

  // Private Cluster Configuration
  enable_private_nodes    = true
  enable_private_endpoint = true

  enable_confidential_nodes = var.enable_confidential_nodes

  fleet_project_grant_service_agent = true

  deletion_protection = var.deletion_protection

  depends_on = [
    module.eab_cluster_project,
    google_project_iam_member.gke_service_agent,
    google_project_iam_member.servicemesh_service_agent,
    google_project_iam_member.multiclusterdiscovery_service_agent,
    data.google_compute_default_service_account.compute_sa
  ]
}

resource "time_sleep" "wait_service_cleanup" {
  depends_on = [module.gke-autopilot.name, module.gke-standard.name]

  destroy_duration = "300s"
}

data "google_project" "workerpool_project" {
  count      = var.cb_private_workerpool_project_id != "" ? 1 : 0
  project_id = var.cb_private_workerpool_project_id
}

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_cluster_to_workerpool_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null && var.cb_private_workerpool_project_id != "" ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "deploy-${local.cluster_project_id}-${data.google_project.workerpool_project[0].project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.eab_cluster_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project[0].number}"]
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "clouddeploy_egress_cluster_to_workerpool_policy" {
  count     = var.service_perimeter_name != null && var.cb_private_workerpool_project_id != "" ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "deploy-${local.cluster_project_id}-${data.google_project.workerpool_project[0].project_id}"
  egress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.eab_cluster_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.workerpool_project[0].number}"]
    operations {
      service_name = "clouddeploy.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

data "google_project" "network_project" {
  project_id = var.network_project_id
}

resource "google_access_context_manager_service_perimeter_egress_policy" "clouddeploy_egress_cluster_to_network_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "${var.network_project_id}-${local.cluster_project_id}"
  egress_from {
    # identities = ["serviceAccount:service-${data.google_project.eab_cluster_project.number}@compute-system.iam.gserviceaccount.com", "serviceAccount:${local.cluster_sa}"]
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.network_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.eab_cluster_project.number}"]
    operations {
      service_name = "monitoring.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudtrace.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "sts.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "trafficdirector.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_egress_policy" "clouddeploy_egress_cluster_to_network_policy" {
  count     = var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "${var.network_project_id}-${local.cluster_project_id}"
  egress_from {
    # identities = ["serviceAccount:service-${data.google_project.eab_cluster_project.number}@compute-system.iam.gserviceaccount.com", "serviceAccount:${local.cluster_sa}"]
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.network_project.number}"
    }
    source_restriction = "SOURCE_RESTRICTION_ENABLED"
  }
  egress_to {
    resources = ["projects/${data.google_project.eab_cluster_project.number}"]
    operations {
      service_name = "monitoring.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "logging.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "cloudtrace.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "sts.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "trafficdirector.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "service_mesh_gke_to_network" {
  count     = var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "servmesh-${local.cluster_project_id}-${var.network_project_id}"
  ingress_from {
    # identities = [google_project_iam_member.servicemesh_service_agent.member]
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.eab_cluster_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.network_project.number}"]
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "service_mesh_gke_to_network" {
  count     = var.service_perimeter_mode == "ENFORCE" && var.service_perimeter_name != null ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "servmesh-${local.cluster_project_id}-${var.network_project_id}"
  ingress_from {
    # identities = [google_project_iam_member.servicemesh_service_agent.member]
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/${data.google_project.eab_cluster_project.number}"
    }
  }
  ingress_to {
    resources = ["projects/${data.google_project.network_project.number}"]
    operations {
      service_name = "compute.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
