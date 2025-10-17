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
  teams = var.hpc ? ["hpc-team-a", "hpc-team-b"] : setunion([
    "cb-frontend",
    "cb-accounts",
    "cb-ledger"],
    !var.single_project ? ["cymbalshops"] : []
  )
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

# Create mock seed folder
module "folder_seed" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = "folders/${var.folder_id}"
  names               = ["seed"]
  deletion_protection = false
}

module "seed_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name                     = "ci-eab-seed"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = module.folder_seed.id
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  activate_apis = [
    "accesscontextmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "apikeys.googleapis.com",
    "binaryauthorization.googleapis.com",
    "binaryauthorization.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "mesh.googleapis.com",
    "monitoring.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "networkmanagement.googleapis.com",
    "orgpolicy.googleapis.com",
    "secretmanager.googleapis.com",
    "servicedirectory.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "trafficdirector.googleapis.com",
  ]

  activate_api_identities = [
    {
      api = "compute.googleapis.com",
      roles = [
        "roles/compute.networkAdmin",
        "roles/compute.admin"
      ]
    },
    {
      api = "cloudbuild.googleapis.com",
      roles = [
        "roles/cloudbuild.builds.builder",
        "roles/cloudbuild.connectionAdmin",
        "roles/cloudbuild.serviceAgent",
      ]
    },
    {
      api   = "workflows.googleapis.com",
      roles = ["roles/workflows.serviceAgent"]
    },
    {
      api   = "config.googleapis.com",
      roles = ["roles/cloudconfig.serviceAgent"]
    },
    {
      api   = "container.googleapis.com",
      roles = ["roles/compute.networkAdmin", "roles/container.serviceAgent"]
    },
    {
      api   = "gkehub.googleapis.com",
      roles = ["roles/compute.networkAdmin", "roles/gkehub.serviceAgent"]
    },
    {
      api   = "artifactregistry.googleapis.com",
      roles = ["roles/artifactregistry.serviceAgent"]
    },
    {
      api   = "storage.googleapis.com",
      roles = []
    }
  ]
}

data "google_organization" "org" {
  organization = var.org_id
}

module "group" {
  for_each = toset(local.teams)
  source   = "terraform-google-modules/group/google"
  version  = "~> 0.7"

  id           = "${each.key}-${random_string.prefix.result}@${data.google_organization.org.domain}"
  display_name = "${each.key}-${random_string.prefix.result}"
  description  = "Group module test group for ${each.key}"
  domain       = data.google_organization.org.domain
}
