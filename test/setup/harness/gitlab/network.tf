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


module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.0"

  project_id                             = module.gitlab_project.project_id
  network_name                           = "eab-vpc-workerpool"
  shared_vpc_host                        = true
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
    {
      name     = "allow-iap-ssh"
      priority = 500
      allow = [
        {
          ports    = [22]
          protocol = "tcp"
        }
      ]

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }

      source_ranges = ["35.235.240.0/20"]
    },
    {
      name     = "allow-service-networking"
      priority = 500
      allow = [
        {
          protocol = "all"
        }
      ]

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }

      source_ranges = ["35.199.192.0/19"]
    },
    {
      name     = "allow-http"
      priority = 500
      allow = [
        {
          ports    = [80]
          protocol = "tcp"
        }
      ]

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }

      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["git-vm"]
    },
    {
      name     = "allow-https"
      priority = 500
      allow = [{
        ports    = [443]
        protocol = "tcp"
      }]

      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }

      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["git-vm"]
    },
  ]

  subnets = [
    {
      subnet_name           = "gitlab-vm-subnet"
      subnet_ip             = "10.2.2.0/24"
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]
}
