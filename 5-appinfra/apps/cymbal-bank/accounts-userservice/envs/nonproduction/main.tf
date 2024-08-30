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
  env                = "nonproduction"
  app_short_name     = "cym-bank"
  service_short_name = "act-usersvc"
}

module "env" {
  source = "../../../../../modules/alloydb-psc-setup"

  env                      = local.env
  cluster_project_id       = var.cluster_project_id
  network_project_id       = var.network_project_id
  cluster_regions          = var.cluster_regions
  app_project_id           = var.app_project_id
  network_name             = var.network_name
  psc_consumer_fwd_rule_ip = var.psc_consumer_fwd_rule_ip
  app_short_name           = local.app_short_name
  service_short_name       = local.service_short_name
}
