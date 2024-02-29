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

  scope_id     = "frontend"
  namespace_id = "frontend"
}

import {
  id = "projects/${var.project_id}/locations/global/features/fleetobservability"
  to = module.env.google_gke_hub_feature.fleet-o11y
}

module "env" {
  source = "../../modules/env_baseline"

  env                    = local.env
  project_id             = var.fleet_project_id
  scope_id               = local.scope_id
  cluster_membership_ids = var.cluster_membership_ids
  namespace_id           = local.namespace_id
}
