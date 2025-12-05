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

# 2-multitenantl

locals {
  env = "development"
  apps = {
    "cymbal-bank" : {
      "ip_address_names" : [
        "frontend-ip",
      ]
      "certificates" : {
        "frontend-example-com" : ["frontend.example.com"]
      }
      "acronym" = "cb",
    }
  }
}

module "multitenant_infra" {
  source = "../../2-multitenant/modules/env_baseline"

  apps                   = local.apps
  cluster_subnetworks    = [var.subnetwork_self_link]
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

  cb_private_workerpool_project_id = var.workerpool_id == null ? google_cloudbuild_worker_pool.pool[0].project : regex("projects/([^/]*)", var.workerpool_id)[0]
}
