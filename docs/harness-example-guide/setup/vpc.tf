locals {
  envs = [for env, enabled in var.enabled_environments : env if enabled]

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

  # Rename the regions of the subnet configs based on the
  # network_regions_to_deploy variable that you provided
  subnet_configs = {
    "us-central1" = {
      subnet_ip          = "10.1.20.0/24"
      secondary_range_01 = "192.168.0.0/18"
      secondary_range_02 = "192.168.64.0/18"
    },
    "us-east4" = {
      subnet_ip          = "10.1.10.0/24"
      secondary_range_01 = "192.168.128.0/18"
      secondary_range_02 = "192.168.192.0/18"
    }
  }
}

# Create mock common folder
module "folder_common" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = ["common"]
  deletion_protection = false
}

# Create mock network folder
module "folder_network" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = ["network"]
  deletion_protection = false
}

# Create mock environment folders
module "folders" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 5.0"

  prefix              = random_string.prefix.result
  parent              = module.folder_seed.id
  names               = local.envs
  deletion_protection = false
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
  source   = "./modules/cluster_network"

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

  subnets = [
    for region in var.network_regions_to_deploy : {
      subnet_name           = "eab-${each.key}-${region}"
      subnet_ip             = local.subnet_configs[region].subnet_ip
      subnet_region         = region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    for region in var.network_regions_to_deploy : "eab-${each.key}-${region}" => [
      {
        range_name    = "eab-${each.key}-${region}-secondary-01"
        ip_cidr_range = local.subnet_configs[region].secondary_range_01
      },
      {
        range_name    = "eab-${each.key}-${region}-secondary-02"
        ip_cidr_range = local.subnet_configs[region].secondary_range_02
      },
    ]
  }
}