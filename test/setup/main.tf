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
  envs = [
    "development",
    "non-production",
    "production",
  ]

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

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 14.0"

  name                     = "ci-enterprise-application"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account

  activate_apis = [
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "storage-api.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbilling.googleapis.com"
  ]
}

# Create mock common folder
module "folder_common" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 4.0"

  prefix = random_string.prefix.result
  parent = "folders/${var.folder_id}"
  names  = ["common"]
}

# Create mock environment folders
module "folders" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 4.0"

  prefix = random_string.prefix.result
  parent = "folders/${var.folder_id}"
  names  = local.envs
}

# Admin roles to folders
resource "google_folder_iam_member" "folder_iam" {
  for_each = { for mapping in local.folder_role_mapping : "${mapping.env}.${mapping.role}" => mapping }

  folder = each.value.folder_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.int_test.email}"
}

# Admin roles to common folder
resource "google_folder_iam_member" "common_folder_iam" {
  for_each = toset(local.folder_admin_roles)
  folder   = module.folder_common.ids["common"]
  role     = each.value
  member   = "serviceAccount:${google_service_account.int_test.email}"
}

# Create SVPC host projects
module "vpc_project" {
  for_each = module.folders.ids
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 14.0"

  name              = "eab-vpc-${each.key}"
  random_project_id = "true"
  org_id            = var.org_id
  folder_id         = each.value
  billing_account   = var.billing_account

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "container.googleapis.com"
  ]
}

# Create VPC networks
module "vpc" {
  for_each = module.vpc_project
  source   = "terraform-google-modules/network/google"
  version  = "~> 9.0"

  project_id      = each.value.project_id
  network_name    = "eab-vpc-${each.key}"
  shared_vpc_host = true

  subnets = [
    {
      subnet_name   = "eab-${each.key}-region01"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-central1"
    },
    {
      subnet_name   = "eab-${each.key}-region02"
      subnet_ip     = "10.10.20.0/24"
      subnet_region = "us-east4"
    },
  ]

  secondary_ranges = {
    "eab-${each.key}-region01" = [
      {
        range_name    = "eab-${each.key}-region01-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-${each.key}-region01-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ]

    "eab-${each.key}-region02" = [
      {
        range_name    = "eab-${each.key}-region02-secondary-01"
        ip_cidr_range = "192.168.128.0/18"
      },
      {
        range_name    = "eab-${each.key}-region02-secondary-02"
        ip_cidr_range = "192.168.192.0/18"
      },
    ]
  }
}
