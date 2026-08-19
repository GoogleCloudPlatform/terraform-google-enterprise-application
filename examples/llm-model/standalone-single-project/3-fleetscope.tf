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

# 3-fleetscope
module "fleetscope_infra" {
  source = "../../../modules/fleetscope"

  env                        = local.env
  cluster_project_id         = module.multitenant_infra.cluster_project_id
  network_project_id         = module.multitenant_infra.network_project_id
  fleet_project_id           = module.multitenant_infra.fleet_project_id
  namespace_ids              = var.teams
  cluster_membership_ids     = module.multitenant_infra.cluster_membership_ids
  config_sync_secret_type    = "none"
  config_sync_policy_dir     = "examples/llm-model/3-fleetscope/config-sync"
  config_sync_repository_url = "https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application"
  config_sync_branch         = "main"
  cluster_service_accounts   = values(module.multitenant_infra.cluster_service_accounts)
  attestation_kms_key        = var.attestation_kms_key

  depends_on = [module.standalone_harness]
}
