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

module "cluster_network" {
  source = "../../modules/cluster_network"

  vpc_name        = "vpc-eab-cluster"
  project_id      = var.project_id
  shared_vpc_host = false
  ncc_config      = var.ncc_config
  subnets = [for i, region in var.regions :
    {
      subnet_name           = "eab-cluster-net-${region}"
      subnet_ip             = cidrsubnet(var.base_cidr, 8, i)
      subnet_region         = region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    for i, region in var.regions :
    "eab-cluster-net-${region}" => [
      {
        range_name    = "eab-cluster-net-${region}-secondary-01"
        ip_cidr_range = cidrsubnet(var.pods_base_cidr, 2, i)
      },
      {
        range_name    = "eab-cluster-net-${region}-secondary-02"
        ip_cidr_range = cidrsubnet(var.services_base_cidr, 2, i)
      },
    ]
  }
}
