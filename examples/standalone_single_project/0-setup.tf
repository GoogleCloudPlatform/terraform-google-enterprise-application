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

# Setup

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id      = var.project_id
  network_name    = "eab-vpc-develop"
  shared_vpc_host = false

  egress_rules = [
    {
      name     = "allow-private-google-access"
      priority = 200
      destination_ranges = [
        "34.126.0.0/18",
        "199.36.153.8/30",
      ]
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name     = "allow-private-google-access-ipv6"
      priority = 200
      destination_ranges = [
        "2600:2d00:2:2000::/64",
        "2001:4860:8040::/42"
      ]
      allow = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    }
  ]


  subnets = [
    {
      subnet_name           = "eab-develop-region01"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    },
    {
      subnet_name           = "eab-develop-region02"
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "us-east4"
      subnet_private_access = true
    },
  ]

  secondary_ranges = {
    "eab-develop-region01" = [
      {
        range_name    = "eab-develop-region01-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-develop-region01-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]

    "eab-develop-region02" = [
      {
        range_name    = "eab-develop-region02-secondary-01"
        ip_cidr_range = "192.168.128.0/18"
      },
      {
        range_name    = "eab-develop-region02-secondary-02"
        ip_cidr_range = "192.168.192.0/18"
      },
    ]
  }
}
