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
  folder_admin_roles = !var.single_project ? [
    "roles/owner",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/compute.networkAdmin",
    "roles/compute.xpnAdmin"
  ] : []

  folder_role_mapping = !var.single_project ? flatten([
    for env in local.envs : [
      for role in local.folder_admin_roles : {
        folder_id = module.folders[local.index].ids[env]
        role      = role
        env       = env
      }
    ]
  ]) : []
}

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  for_each = !var.single_project ? { (local.index) = true } : {}

  name                     = "ci-enterprise-application"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  activate_apis = [
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "storage-api.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbilling.googleapis.com"
  ]

  activate_api_identities = [
    {
      api   = "compute.googleapis.com",
      roles = []
    },
    {
      api = "cloudbuild.googleapis.com",
      roles = [
        "roles/cloudbuild.builds.builder",
        "roles/cloudbuild.connectionAdmin",
      ]
    },
    {
      api   = "workflows.googleapis.com",
      roles = ["roles/workflows.serviceAgent"]
    },
    {
      api   = "config.googleapis.com",
      roles = ["roles/cloudconfig.serviceAgent"]
    }
  ]
}
# Create mock common folder
module "folder_common" {
  for_each = !var.single_project ? { (local.index) = true } : {}

  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = "folders/${var.folder_id}"
  names               = ["common"]
  deletion_protection = false
}

# Create mock environment folders
module "folders" {
  for_each = !var.single_project ? { (local.index) = true } : {}

  source  = "terraform-google-modules/folders/google"
  version = "~> 5.0"

  prefix              = random_string.prefix.result
  parent              = "folders/${var.folder_id}"
  names               = local.envs
  deletion_protection = false
}

# Admin roles to folders
resource "google_folder_iam_member" "folder_iam" {
  for_each = { for mapping in local.folder_role_mapping : "${mapping.env}.${mapping.role}" => mapping }

  folder = each.value.folder_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.int_test[local.index].email}"
}

# Admin roles to common folder
resource "google_folder_iam_member" "common_folder_iam" {
  for_each = toset(local.folder_admin_roles)
  folder   = module.folder_common[local.index].ids["common"]
  role     = each.value
  member   = "serviceAccount:${google_service_account.int_test[local.index].email}"
}

# Create SVPC host projects
module "vpc_project" {
  for_each = !var.single_project ? { for i, folder in module.folders[local.index].ids : (i) => folder } : {}
  source   = "terraform-google-modules/project-factory/google"
  version  = "~> 18.0"

  name                     = "eab-vpc-${each.key}"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = each.value
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

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
  version  = "~> 10.0"

  project_id      = each.value.project_id
  network_name    = "eab-vpc-${each.key}"
  shared_vpc_host = true

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
        "2600:2d00:0002:2000::/64",
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
      subnet_name           = "eab-${each.key}-region01"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    },
    {
      subnet_name           = "eab-${each.key}-region02"
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = "us-east4"
      subnet_private_access = true
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

resource "google_compute_router" "nat_router" {
  for_each = module.vpc

  name    = "nat-router-us-central-1"
  region  = "us-central1"
  network = each.value.network_self_link
  project = each.value.project_id
}

resource "google_compute_router_nat" "cloud_nat" {
  for_each = module.vpc

  name                               = "cloud-nat"
  router                             = google_compute_router.nat_router[each.key].name
  region                             = google_compute_router.nat_router[each.key].region
  project                            = each.value.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
