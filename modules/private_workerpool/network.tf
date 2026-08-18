/**
 * Copyright 2025 Google LLC
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
  nat_proxy_vm_ip_range = "10.1.1.0/24"
  network_id            = var.network_id == null ? module.vpc[0].network_id : var.network_id
  network_project_id    = regex("projects/([^/]*)/", local.network_id)[0]
  network_id_splited    = split("/", local.network_id)
  network_name          = local.network_id_splited[length(local.network_id_splited) - 1]
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.0"
  count   = var.network_id == null ? 1 : 0

  project_id                             = var.project_id
  network_name                           = "eab-vpc-workerpool"
  shared_vpc_host                        = false
  delete_default_internet_gateway_routes = true

  ingress_rules = [
    {
      name     = "allow-ssh"
      priority = 500
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
  ]

  subnets = []
}
