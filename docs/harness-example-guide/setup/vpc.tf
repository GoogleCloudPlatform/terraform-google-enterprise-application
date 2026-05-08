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
  envs = [for env, enabled in var.enabled_environments : env if enabled]

  # Nested map defining distinct CIDR blocks per environment and per region.
  # This ensures 100% isolation by default, but prevents IP conflicts
  # if the user decides to peer these VPCs together in the future.
  env_subnet_configs = {
    "development" = {
      psc_ip = "10.10.0.5",
      "us-central1" = {
        subnet_ip          = "10.10.1.0/24"
        secondary_range_01 = "10.11.0.0/18"
        secondary_range_02 = "10.12.0.0/18"
      },
      "us-east4" = {
        subnet_ip          = "10.10.2.0/24"
        secondary_range_01 = "10.13.0.0/18"
        secondary_range_02 = "10.14.0.0/18"
      }
    },
    "nonproduction" = {
      psc_ip = "10.20.0.5",
      "us-central1" = {
        subnet_ip          = "10.20.1.0/24"
        secondary_range_01 = "10.21.0.0/18"
        secondary_range_02 = "10.22.0.0/18"
      },
      "us-east4" = {
        subnet_ip          = "10.20.2.0/24"
        secondary_range_01 = "10.23.0.0/18"
        secondary_range_02 = "10.24.0.0/18"
      }
    },
    "production" = {
      psc_ip = "10.30.0.5",
      "us-central1" = {
        subnet_ip          = "10.30.1.0/24"
        secondary_range_01 = "10.31.0.0/18"
        secondary_range_02 = "10.32.0.0/18"
      },
      "us-east4" = {
        subnet_ip          = "10.30.2.0/24"
        secondary_range_01 = "10.33.0.0/18"
        secondary_range_02 = "10.34.0.0/18"
      }
    }
  }
}

module "folder_common" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = ["common"]
  deletion_protection = false
}

module "folder_network" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = ["network"]
  deletion_protection = false
}

module "folders_envs" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 5.0"

  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = local.envs
  deletion_protection = false
}

# SVPC host projects
module "vpc_project" {
  for_each = { for i, folder in module.folders_envs.ids : (i) => folder }
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 18.0"

  name                     = "eab-vpc-${each.key}"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = module.folder_network.ids["network"]
  billing_account          = var.billing_account
  deletion_policy          = var.project_deletion_policy
  default_service_account  = "KEEP"

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "iam.googleapis.com",
    "networkmanagement.googleapis.com",
    "networkservices.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

module "cluster_vpc" {
  for_each = module.vpc_project
  source   = "./modules/cluster_network"

  project_id      = each.value.project_id
  vpc_name        = "eab-vpc-${each.key}"
  shared_vpc_host = true

  private_service_connect_ip = local.env_subnet_configs[each.key].psc_ip
  network_regions_to_deploy  = var.network_regions_to_deploy

  ingress_rules = [
    {
      name     = "fw-${each.key}-allow-health-check"
      priority = 1000
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
      allow = [
        {
          protocol = "tcp"
        }
      ]
    },
    {
      name     = "fw-${each.key}-allow-proxies"
      priority = 1000
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = var.proxy_source_ranges
      allow = [
        {
          protocol = "tcp"
        }
      ]
    }
  ]

  subnets = [
    for region in var.network_regions_to_deploy : {
      subnet_name = "eab-${each.key}-${region}"
      # Dynamically lookup based on the environment (each.key) and the region
      subnet_ip             = local.env_subnet_configs[each.key][region].subnet_ip
      subnet_region         = region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    for region in var.network_regions_to_deploy : "eab-${each.key}-${region}" => [
      {
        range_name    = "eab-${each.key}-${region}-secondary-01"
        ip_cidr_range = local.env_subnet_configs[each.key][region].secondary_range_01
      },
      {
        range_name    = "eab-${each.key}-${region}-secondary-02"
        ip_cidr_range = local.env_subnet_configs[each.key][region].secondary_range_02
      },
    ]
  }
}
