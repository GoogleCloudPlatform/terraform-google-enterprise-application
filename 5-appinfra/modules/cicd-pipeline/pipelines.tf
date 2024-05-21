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


locals {
  fleet_membership_re = "//gkehub.googleapis.com/(.*)$"
}

# cloud deploy service account
resource "google_service_account" "cloud_deploy" {
  project                      = var.project_id
  account_id                   = "deploy-${local.service_name}"
  create_ignore_already_exists = true
}

resource "google_clouddeploy_target" "development" {
  # one CloudDeploy target per target defined in vars

  project  = var.project_id
  name     = "${local.service_name}-dev"
  location = var.region

  anthos_cluster {
    membership = regex(local.fleet_membership_re, var.cluster_membership_id_dev)[0]
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
  name                        = "delivery-artifacts-development-${data.google_project.project.number}-${local.service_name}"
  uniform_bucket_level_access = true
  location                    = var.region
  force_destroy               = var.buckets_force_destroy
}

# give CloudDeploy SA access to administrate to delivery artifact bucket
resource "google_storage_bucket_iam_member" "delivery_artifacts_development" {
  bucket = google_storage_bucket.delivery_artifacts_development.name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.admin"
}

resource "google_clouddeploy_target" "non_prod" {
  # one CloudDeploy target per target defined in vars
  for_each = { for i, v in var.cluster_membership_ids_nonprod : i => v }

  project  = var.project_id
  name     = "${local.service_name}-nonprod-${each.key}"
  location = var.region

  anthos_cluster {
    membership = regex(local.fleet_membership_re, each.value)[0]
  }

  execution_configs {
    artifact_storage = "gs://${google_storage_bucket.delivery_artifacts_non_prod.name}"
    service_account  = google_service_account.cloud_deploy.email
    usages = [
      "RENDER",
      "DEPLOY"
    ]
  }
}

# GCS bucket used by Cloud Deploy for delivery artifact storage
resource "google_storage_bucket" "delivery_artifacts_non_prod" {
  project                     = var.project_id
  name                        = "delivery-artifacts-non-prod-${data.google_project.project.number}-${local.service_name}"
  uniform_bucket_level_access = true
  location                    = var.region
  force_destroy               = var.buckets_force_destroy
}

# give CloudDeploy SA access to administrate to delivery artifact bucket
resource "google_storage_bucket_iam_member" "delivery_artifacts_non_prod" {
  bucket = google_storage_bucket.delivery_artifacts_non_prod.name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.admin"
}

resource "google_clouddeploy_target" "prod" {
  # one CloudDeploy target per target defined in vars
  for_each = { for i, v in var.cluster_membership_ids_prod : i => v }

  project  = var.project_id
  name     = "${local.service_name}-prod-${each.key}"
  location = var.region

  anthos_cluster {
    membership = regex(local.fleet_membership_re, each.value)[0]
  }

  execution_configs {
    artifact_storage = "gs://${google_storage_bucket.delivery_artifacts_prod.name}"
    service_account  = google_service_account.cloud_deploy.email
    usages = [
      "RENDER",
      "DEPLOY"
    ]
  }
}

# GCS bucket used by Cloud Deploy for delivery artifact storage
resource "google_storage_bucket" "delivery_artifacts_prod" {
  project                     = var.project_id
  name                        = "delivery-artifacts-prod-${data.google_project.project.number}-${local.service_name}"
  uniform_bucket_level_access = true
  location                    = var.region
  force_destroy               = var.buckets_force_destroy
}

# give CloudDeploy SA access to administrate to delivery artifact bucket
resource "google_storage_bucket_iam_member" "delivery_artifacts_prod" {
  bucket = google_storage_bucket.delivery_artifacts_prod.name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.admin"
}
