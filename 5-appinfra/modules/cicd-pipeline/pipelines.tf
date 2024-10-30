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
  service_name_short  = substr(var.service_name, 0, 4)
}

# cloud deploy service account
resource "google_service_account" "cloud_deploy" {
  project                      = var.project_id
  account_id                   = "deploy-${var.service_name}"
  create_ignore_already_exists = true
}

resource "google_clouddeploy_target" "clouddeploy_targets" {
  # one CloudDeploy target per cluster_membership_id defined in vars
  for_each = local.memberships_map

  project  = var.project_id
  name     = trimsuffix(substr("${local.service_name_short}-${trimprefix(regex(local.membership_re, each.value)[2], "cluster-")}", 0, 25), "-")
  location = var.region

  anthos_cluster {
    membership = regex(local.fleet_membership_re, each.value)[0]
  }

  execution_configs {
    artifact_storage = "gs://${google_storage_bucket.delivery_artifacts[split("-", each.value)[length(split("-", each.value)) - 1]].name}"
    service_account  = google_service_account.cloud_deploy.email
    usages = [
      "RENDER",
      "DEPLOY"
    ]
  }

  depends_on = [google_storage_bucket.delivery_artifacts]
}

# GCS bucket used by Cloud Deploy for delivery artifact storage
resource "google_storage_bucket" "delivery_artifacts" {
  for_each = var.env_cluster_membership_ids

  project                     = var.project_id
  name                        = "artifacts-${each.key}-${data.google_project.project.number}-${var.service_name}"
  uniform_bucket_level_access = true
  location                    = regex(local.membership_re, each.value.cluster_membership_ids[0])[1]
  force_destroy               = var.buckets_force_destroy
}

# give CloudDeploy SA access to administrate to delivery artifact bucket
resource "google_storage_bucket_iam_member" "delivery_artifacts" {
  for_each = var.env_cluster_membership_ids

  bucket = google_storage_bucket.delivery_artifacts[each.key].name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.admin"
}
