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

# 2-multitenant

locals {
  env = "development"
  apps = {
    "llm-model" : {
      "acronym"          = "llm",
      "ip_address_names" = [],
      "certificates"     = {},
    }
  }
}

module "multitenant_infra" {
  source = "../../../modules/gke"

  apps                   = local.apps
  cluster_subnetworks    = module.standalone_harness.subnets_self_links
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

  cb_private_workerpool_project_id = module.standalone_harness.workerpool_project_id

  depends_on = [module.standalone_harness]
}
