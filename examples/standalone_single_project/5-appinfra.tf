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

# 5-appinfra

# app_01
locals {
  cicd_apps = {
    "app-01" = {
      application_name = "default-example"
      service_name     = "hello-world"
      team_name        = "default"
      repo_branch      = "main"
    }
  }
}

module "cicd" {
  source   = "../../5-appinfra/modules/cicd-pipeline"
  for_each = local.cicd_apps

  project_id                 = var.project_id
  region                     = var.region
  env_cluster_membership_ids = module.multitenant_infra.cluster_membership_ids

  service_name           = each.value.service_name
  team_name              = each.value.team_name
  repo_name              = "eab-${each.value.application_name}-${each.value.service_name}"
  repo_branch            = each.value.repo_branch
  app_build_trigger_yaml = "cloudbuild.yaml"

  buckets_force_destroy = true
}