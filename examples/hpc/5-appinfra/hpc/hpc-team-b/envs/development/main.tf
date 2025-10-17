/**
 * Copyright 2025 Google LLC
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

/* TODO: When renaming the environment, consider updating:
 * - the cluster environment in (2-multitenant)
 * - the fleetscope namespace suffixes (3-fleetscope)
 * - the infrastructure project in (4-appfactory)
 */
locals {
  env = "development"
}

module "provision-monte-carlo-infra" {
  source = "../../modules/hpc-monte-carlo-infra"

  infra_project            = local.app_project_id
  cluster_project          = local.cluster_project_id
  cluster_project_number   = local.cluster_project_number
  region                   = "us-central1"
  env                      = local.env
  cluster_service_accounts = local.cluster_service_accounts
  bucket_force_destroy     = var.bucket_force_destroy
  workerpool_id            = data.terraform_remote_state.bootstrap.outputs.cb_private_workerpool_id
  team                     = "hpc-team-b"
  logging_bucket           = var.logging_bucket
  bucket_kms_key           = var.bucket_kms_key
  bucket_prefix            = var.bucket_prefix
}
