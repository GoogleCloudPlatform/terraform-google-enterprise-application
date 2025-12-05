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
  envs = (var.branch_name == "release-please--branches--main" || startswith(var.branch_name, "test-all/")) ? [
    "development",
    "nonproduction",
    "production",
    ] : var.branch_name == "" ? [
    "development",
    "nonproduction",
  ] : ["development"]
  folder_admin_roles = [
    "roles/owner",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/compute.networkAdmin",
    "roles/compute.xpnAdmin"
  ]

  folder_role_mapping = flatten([
    for env in local.envs : [
      for role in local.folder_admin_roles : {
        folder_id = module.folders.ids[env]
        role      = role
        env       = env
      }
    ]
  ])
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

# Create mock common folder
module "folder_common" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = var.seed_folder_id
  names               = ["common"]
  deletion_protection = false
}

# Create mock network folder
module "folder_network" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = var.seed_folder_id
  names               = ["network"]
  deletion_protection = false
}

# Create mock environment folders
module "folders" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 5.0"

  prefix              = random_string.prefix.result
  parent              = var.seed_folder_id
  names               = local.envs
  deletion_protection = false
}

# Admin roles to folders
resource "google_folder_iam_member" "folder_iam" {
  for_each = { for mapping in local.folder_role_mapping : "${mapping.env}.${mapping.role}" => mapping }

  folder = each.value.folder_id
  role   = each.value.role
  member = "serviceAccount:${var.sa_email}"
}

# Admin roles to common folder
resource "google_folder_iam_member" "common_folder_iam" {
  for_each = toset(local.folder_admin_roles)
  folder   = module.folder_common.ids["common"]
  role     = each.value
  member   = "serviceAccount:${var.sa_email}"
}

# Admin roles to network folder
resource "google_folder_iam_member" "networ_folder_iam" {
  for_each = toset(local.folder_admin_roles)
  folder   = module.folder_network.ids["network"]
  role     = each.value
  member   = "serviceAccount:${var.sa_email}"
}

# Create SVPC host projects
module "vpc_project" {
  for_each = { for i, folder in module.folders.ids : (i) => folder }
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 18.0"

  name                     = "eab-vpc-${each.key}"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = module.folder_network.ids["network"]
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
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
  source   = "../../modules/cluster_network"

  project_id      = each.value.project_id
  vpc_name        = "eab-vpc-${each.key}"
  shared_vpc_host = true

  ingress_rules = [
    {
      name     = "allow-ssh"
      priority = 65534
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
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name     = "fw-allow-health-check"
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
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name     = "fw-allow-proxies"
      priority = 1000
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["10.129.0.0/23"]
      allow = [
        {
          protocol = "tcp"
        }
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    }
  ]

  subnets = concat([{
    subnet_name           = "eab-${each.key}-us-central1"
    subnet_ip             = "10.1.20.0/24"
    subnet_region         = "us-central1"
    subnet_private_access = true
    }], !var.agent ? [{
    subnet_name           = "eab-${each.key}-us-east4"
    subnet_ip             = "10.1.10.0/24"
    subnet_region         = "us-east4"
    subnet_private_access = true
    }] : [{
    subnet_name   = "sb-proxy-only-us-central1"
    subnet_ip     = "10.129.0.0/23"
    purpose       = "REGIONAL_MANAGED_PROXY"
    subnet_region = "us-central1"
    role          = "ACTIVE"
  }])

  secondary_ranges = merge({
    "eab-${each.key}-us-central1" = [
      {
        range_name    = "eab-${each.key}-us-central1-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-${each.key}-us-central1-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ] }, !var.agent ? {
    "eab-${each.key}-us-east4" = [
      {
        range_name    = "eab-${each.key}-us-east4-secondary-01"
        ip_cidr_range = "192.168.128.0/18"
      },
      {
        range_name    = "eab-${each.key}-us-east4-secondary-02"
        ip_cidr_range = "192.168.192.0/18"
      },
  ] } : {})
}
