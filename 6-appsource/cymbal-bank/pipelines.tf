# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# user-defined module setting up a CloudBuild + CloudDeploy CICD pipeline
module "ci-cd-pipeline" {
  source = "./modules/ci-cd-pipeline"

  # create CICD pipeline per team
  for_each = toset(local.services)

  project_id         = var.project_id
  region             = var.region
  container_registry = google_artifact_registry_repository.container_registry
  repo_name          = var.sync_repo
  service            = each.value
  targets            = [google_clouddeploy_target.development]
  repo_branch        = var.sync_branch
  cloud_deploy_sa    = google_service_account.cloud_deploy

  depends_on = [
    module.enabled_google_apis
  ]
}

# cloud deploy service account
resource "google_service_account" "cloud_deploy" {
  project    = var.project_id
  account_id = "cloud-deploy"
}

resource "google_clouddeploy_target" "development" {
  # one CloudDeploy target per target defined in vars

  project  = var.project_id
  name     = "development"
  location = var.region

  anthos_cluster {
    membership = var.cluster_membership_id
  }

  execution_configs {
    artifact_storage = "gs://${google_storage_bucket.delivery_artifacts_development.name}"
    service_account  = google_service_account.cloud_deploy.email
    usages = [
      "RENDER",
      "DEPLOY"
    ]
  }
}

# GCS bucket used by Cloud Deploy for delivery artifact storage
resource "google_storage_bucket" "delivery_artifacts_development" {
  project                     = var.project_id
  name                        = "delivery-artifacts-development-${data.google_project.project.number}"
  uniform_bucket_level_access = true
  location                    = var.region
}

# give CloudDeploy SA access to administrate to delivery artifact bucket
resource "google_storage_bucket_iam_member" "delivery_artifacts_development" {
  bucket = google_storage_bucket.delivery_artifacts_development.name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.admin"
}
