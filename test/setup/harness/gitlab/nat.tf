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
module "nat" {
  source                = "../../../../modules/nat"
  network_id            = module.vpc.network_id
  region                = var.region
  nat_proxy_vm_ip_range = "10.1.1.0/24"
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 18.0"

  project_id   = module.vpc.project_id
  network_name = module.vpc.network_name

  rules = [{
    name                    = "allow-pool-to-nat"
    direction               = "INGRESS"
    priority                = 1000
    source_tags             = null
    source_service_accounts = null
    target_tags             = ["nat-gateway"]
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_range.address}/${google_compute_global_address.worker_range.prefix_length}"]

    allow = [{
      protocol = "all"
      ports    = null
    }]

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    }
  ]
}
