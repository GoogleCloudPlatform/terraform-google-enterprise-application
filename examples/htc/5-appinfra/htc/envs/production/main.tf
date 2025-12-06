# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  env              = "production"
  application_name = "htc"
  service_name     = "htc"
  team_name        = "default"
  repo_name        = "eab-${local.application_name}-${local.service_name}"
  repo_branch      = "main"
}

module "app" {
  source = "../../modules/cicd-pipeline"

  project_id                 = local.app_admin_project
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in local.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = local.service_name
  team_name              = local.team_name
  repo_name              = local.repo_name
  repo_branch            = local.repo_branch
  app_build_trigger_yaml = "cloudbuild.yaml"

  buckets_force_destroy = var.buckets_force_destroy

  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config
  workerpool_id                  = data.terraform_remote_state.bootstrap.outputs.cb_private_workerpool_id
  access_level_name              = var.access_level_name
  logging_bucket                 = var.logging_bucket
  bucket_kms_key                 = var.bucket_kms_key

  attestation_kms_key                = var.attestation_kms_key
  attestor_id                        = contains(var.environment_names, "production") ? data.terraform_remote_state.fleetscope["production"].outputs.attestor_id : data.terraform_remote_state.fleetscope[var.environment_names[0]].outputs.attestor_id
  binary_authorization_image         = data.terraform_remote_state.bootstrap.outputs.binary_authorization_image
  binary_authorization_repository_id = data.terraform_remote_state.bootstrap.outputs.binary_authorization_repository_id
}

module "htc-infra" {
  source = "../../modules/htc-infra"

  service_name           = local.service_name
  gke_cluster_names      = local.gke_cluster_names
  infra_project          = local.app_infra_project
  region                 = var.region
  network_self_link      = var.envs[local.env].network_self_link
  network_name           = local.network_name
  team                   = var.team
  admin_project          = local.app_admin_project
  cluster_project_id     = local.cluster_project_id
  cluster_project_number = local.cluster_project_number
  env                    = local.env
}
