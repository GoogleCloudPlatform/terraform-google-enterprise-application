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
  service_name     = "accounts-userservice"
  repo_name        = "eab-${local.application_name}-${local.service_name}"
  repo_branch      = "main"
}

module "app" {
  source = "../../../../modules/cicd-pipeline"

  project_id                     = var.project_id
  region                         = var.region
  cluster_membership_id_dev      = var.cluster_membership_id_dev
  cluster_membership_ids_nonprod = var.cluster_membership_ids_nonprod
  cluster_membership_ids_prod    = var.cluster_membership_ids_prod

  service     = local.service_name
  repo_name   = local.repo_name
  repo_branch = local.repo_branch

  buckets_force_destroy = var.buckets_force_destroy
}
