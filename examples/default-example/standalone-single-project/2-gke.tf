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

locals {
  env = "development"
  apps = {
    "default-example" : {
      "acronym"          = "de",
      "ip_address_names" = [],
      "certificates"     = {},
    }
  }
}

module "multitenant_infra" {
  source = "../../../modules/gke"

  apps                   = local.apps
  cluster_subnetworks    = [for i, j in module.standalone_harness.subnets : j.self_link if !strcontains(i, "proxy")]
  network_project_id     = module.standalone_harness.project_id
  env                    = local.env
  cluster_type           = "AUTOPILOT"
  cluster_prefix         = "de"
  create_cluster_project = false
  # ignore below vars because we are reusing an existing project
  org_id                 = null
  folder_id              = null
  billing_account        = null
  service_perimeter_name = var.service_perimeter_name
  service_perimeter_mode = var.service_perimeter_mode
  access_level_name      = var.access_level_name
  deletion_protection    = false

  depends_on = [module.standalone_harness]
}
