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
  env = "nonproduction"
}

module "env" {
  source = "../../modules/env_baseline"

  env                      = local.env
  cluster_project_id       = local.cluster_project_id
  network_project_id       = local.network_project_id
  fleet_project_id         = local.fleet_project_id
  namespace_ids            = var.namespace_ids
  cluster_membership_ids   = local.cluster_membership_ids
  cluster_service_accounts = values(local.cluster_service_accounts)

  config_sync_secret_type    = var.config_sync_secret_type
  config_sync_repository_url = var.config_sync_repository_url
  config_sync_branch         = var.config_sync_branch
  config_sync_policy_dir     = var.config_sync_policy_dir

  enable_kueue = var.enable_kueue

  attestation_kms_key         = var.attestation_kms_key
  attestation_evaluation_mode = var.attestation_evaluation_mode

  disable_istio_on_namespaces = var.disable_istio_on_namespaces
}
