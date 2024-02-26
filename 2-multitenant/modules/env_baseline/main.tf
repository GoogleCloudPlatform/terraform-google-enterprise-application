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
}

// Import the subnetworks
data "google_compute_subnetwork" "default" {
  for_each  = { for value in var.cluster_subnetworks : regex(local.subnetworks_re, value)[0] => value }
  self_link = each.value
}

// Create a GKE cluster in each subnetwork
module "gke" {
  // TODO(apeabody) replace when ~> 30.1 released
  // source  = "terraform-google-modules/kubernetes-engine/google"
  // version = "~> 30.0"

  source = "github.com/terraform-google-modules/terraform-google-kubernetes-engine?ref=6b267bd91362cd78e06850a267a04c0fd2427b1c"

  for_each = data.google_compute_subnetwork.default
  name     = "cluster-${each.value.region}-${var.env}"

  project_id        = each.value.project
  regional          = true
  region            = each.value.region
  network           = regex(local.networks_re, each.value.network)[0]
  subnetwork        = each.value.name
  ip_range_pods     = each.value.secondary_ip_range[0].range_name
  ip_range_services = each.value.secondary_ip_range[1].range_name
  release_channel   = var.release_channel
  fleet_project     = var.project_id

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

  deletion_protection = false # set to true to prevent the module from deleting the cluster on destroy
}
