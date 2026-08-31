/**
 * Copyright 2026 Google LLC
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

module "hub_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.1"

  project_id      = module.seed_project.project_id
  network_name    = "vpc-eab-hub"
  shared_vpc_host = false

  subnets = [
    {
      subnet_name   = "sb-h-svpc-${var.region}"
      subnet_ip     = "10.8.0.0/18"
      subnet_region = var.region
      description   = "Network subnet for ${var.region}"
    },
    {
      subnet_name           = "sb-h-svpc-${var.region}-proxy"
      subnet_ip             = "10.26.0.0/23"
      subnet_region         = var.region
      subnet_flow_logs      = false
      subnet_private_access = false
      description           = "Network proxy-only subnet for ${var.region}"
      role                  = "ACTIVE"
      purpose               = "REGIONAL_MANAGED_PROXY"
    },
  ]
}

module "network_connectivity_center_star" {
  source  = "terraform-google-modules/network/google//modules/network-connectivity-center"
  version = "~> 18.0"

  project_id   = module.seed_project.project_id
  ncc_hub_name = "eab-hub-star"
  ncc_hub_labels = {
    "module" = "ncc"
  }
  ncc_hub_preset_topology = "STAR"
  ncc_groups = {
    "center" = {
      name = "center"
      labels = {
        "module" = "ncc"
      }
    }
    "edge" = {
      name                 = "edge"
      auto_accept_projects = [for i in module.harness_project : i.project_id]
    }
  }
  spoke_labels = {
    "created-by" = "terraform-google-enterprise-application"
  }
}
