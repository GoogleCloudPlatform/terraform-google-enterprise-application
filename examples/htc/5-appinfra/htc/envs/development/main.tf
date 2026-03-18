# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  env              = "development"
  application_name = "htc"
}

module "htc-infra" {
  source = "../../modules/htc-infra"

  service_name           = local.application_name
  gke_cluster_names      = local.gke_cluster_names
  infra_project          = local.app_infra_project
  region                 = var.region
  network_self_link      = var.envs[local.env].network_self_link
  network_name           = local.network_name
  team                   = var.team
  admin_project          = local.app_admin_project
  cluster_project_id     = local.cluster_project_id
  cluster_project_number = local.cluster_project_number
  env                    = local.env
  regions                = local.regions
  compute_class          = "autopilot-spot"
}
