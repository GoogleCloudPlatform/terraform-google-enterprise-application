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

locals {
  env = "development"
  apps = {
    "cymbal-bank" : {
      "ip_address_names" : [
        "frontend-ip",
      ]
      "certificates" : {
        "frontend-example-com" : ["frontend.example.com"]
      }
      "acronym" = "cb",
    }
  }
}

module "multitenant_infra" {
  source = "../../modules/gke"

  apps                   = local.apps
  cluster_subnetworks    = module.cluster_network.subnets_self_links
  network_project_id     = var.project_id
  env                    = local.env
  cluster_type           = "AUTOPILOT"
  create_cluster_project = false
  # ignore below vars because we are reusing an existing project
  org_id                 = null
  folder_id              = null
  billing_account        = null
  service_perimeter_name = var.service_perimeter_name
  service_perimeter_mode = var.service_perimeter_mode
  access_level_name      = var.access_level_name
  deletion_protection    = false

  cb_private_workerpool_project_id = var.project_id
}

module "fleetscope_infra" {
  source = "../../modules/fleetscope"

  env                           = local.env
  cluster_project_id            = module.multitenant_infra.cluster_project_id
  network_project_id            = module.multitenant_infra.network_project_id
  fleet_project_id              = module.multitenant_infra.fleet_project_id
  namespace_ids                 = var.teams
  cluster_membership_ids        = module.multitenant_infra.cluster_membership_ids
  
  config_sync_secret_type    = var.config_sync_secret_type
  config_sync_repository_url = var.config_sync_repository_url
  config_sync_branch         = var.config_sync_branch
  config_sync_policy_dir     = var.config_sync_policy_dir

  cluster_service_accounts      = values(module.multitenant_infra.cluster_service_accounts)
  attestation_kms_key           = var.attestation_kms_key
  enable_multicluster_discovery = true
}
