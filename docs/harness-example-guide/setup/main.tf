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

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

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
  deletion_policy          = var.project_deletion_policy
  default_service_account  = "KEEP"

  activate_apis = [
    "accesscontextmanager.googleapis.com",
    "aiplatform.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "anthospolicycontroller.googleapis.com",
    "apikeys.googleapis.com",
    "artifactregistry.googleapis.com",
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
    "modelarmor.googleapis.com",
    "monitoring.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "networkmanagement.googleapis.com",
    "networkservices.googleapis.com",
    "notebooks.googleapis.com",
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
        "roles/compute.serviceAgent",
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
    },
    {
      api   = "networkservices.googleapis.com",
      roles = []
    },
    {
      api   = "aiplatform.googleapis.com",
      roles = ["roles/aiplatform.serviceAgent"]
    }
  ]
}

resource "google_storage_bucket" "terraform_state" {
  project                     = module.seed_project.project_id
  name                        = "tfstate-eab-harness-${random_string.prefix.result}"
  location                    = var.region
  labels                      = var.storage_bucket_labels
  force_destroy               = var.tfstate_bucket_force_destroy
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

  dynamic "encryption" {
    for_each = var.encrypt_gcs_bucket_tfstate ? ["encryption"] : []
    content {
      default_kms_key_name = module.kms_tfstate.keys["state-key"]
    }
  }
}
