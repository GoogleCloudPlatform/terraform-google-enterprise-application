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
  application_name = "cymbal-bank"
  service_name     = "balancereader"
  team_name        = "ledger"
  repo_name        = "eab-${local.application_name}-${local.team_name}-${local.service_name}"
  repo_branch      = "main"
}

module "app" {
  source = "../../modules/cicd-pipeline"

  project_id                 = local.app_admin_project
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids

  cluster_service_accounts = { for i, sa in local.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = local.service_name
  team_name              = local.team_name
  repo_name              = local.repo_name
  repo_branch            = local.repo_branch
  app_build_trigger_yaml = "src/${local.team_name}/cloudbuild.yaml"

  additional_substitutions = {
    _SERVICE = local.service_name
    _TEAM    = local.team_name
  }

  ci_build_included_files = ["src/${local.team_name}/**", "src/components/**"]

  buckets_force_destroy = var.buckets_force_destroy

  cloudbuildv2_repository_config = var.cloudbuildv2_repository_config

  workerpool_id     = data.terraform_remote_state.bootstrap.outputs.cb_private_workerpool_id
  access_level_name = var.access_level_name
  logging_bucket    = var.logging_bucket
}
