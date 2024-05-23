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
  env = "development"
}

module "env" {
  source = "../../modules/env_baseline"

  apps                = var.apps
  env                 = local.env
  org_id              = var.envs[local.env].org_id
  folder_id           = var.envs[local.env].folder_id
  network_project_id  = var.envs[local.env].network_project_id
  billing_account     = var.envs[local.env].billing_account
  cluster_subnetworks = [var.envs[local.env].subnets_self_links[0]]
}
