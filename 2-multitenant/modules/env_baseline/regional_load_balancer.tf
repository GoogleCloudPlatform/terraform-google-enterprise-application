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

data "google_compute_network" "network" {
  project = var.network_project_id
  name    = regex(local.projects_re, local.network)[0]
}

module "regional_load_balancer" {
  source   = "../regional_load_balancer"
  for_each = var.create_regional_loadbalancer ? local.subnets : {}

  vpc_id             = data.google_compute_network.network.id
  project_id         = local.cluster_project_id
  network_project_id = var.network_project_id
  region             = data.google_compute_subnetwork.default[each.key].region
}
