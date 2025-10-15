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
  name     = trimsuffix(substr("${local.service_name_short}-${trimprefix(regex(local.membership_re, each.value)[2], "cluster-")}", 0, 21), "-")
  location = var.region

  anthos_cluster {
    membership = regex(local.fleet_membership_re, each.value)[0]
  }

  execution_configs {
    artifact_storage = "gs://${module.delivery_artifacts[split("-", each.value)[length(split("-", each.value)) - 1]].name}"
    service_account  = google_service_account.cloud_deploy.email
    worker_pool      = var.workerpool_id
    usages = [
      "RENDER",
      "DEPLOY"
    ]
  }

  depends_on = [module.delivery_artifacts]
}

# GCS bucket used by Cloud Deploy for delivery artifact storage
module "delivery_artifacts" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 11.0"

  for_each = var.env_cluster_membership_ids

  name              = "${var.bucket_prefix}-artifacts-${each.key}-${data.google_project.project.number}-${var.service_name}"
  project_id        = var.project_id
  location          = regex(local.membership_re, each.value.cluster_membership_ids[0])[1]
  log_bucket        = var.logging_bucket
  log_object_prefix = "ar-${each.key}-${var.service_name}"
  force_destroy     = var.buckets_force_destroy

  public_access_prevention = "enforced"

  versioning = true
  encryption = var.bucket_kms_key == null ? null : {
    default_kms_key_name = var.bucket_kms_key
  }

  internal_encryption_config = var.bucket_kms_key == null ? {
    create_encryption_key = true
    prevent_destroy       = !var.buckets_force_destroy
  } : {}


  # Module does not support values not know before apply (member and role are used to create the index in for_each)
  # https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v10.0.2/modules/simple_bucket/main.tf#L122
  # iam_members = [{
  #   role   = "roles/storage.admin"
  #   member = google_service_account.cloud_deploy.member
  # }]

  depends_on = [time_sleep.wait_cmek_iam_propagation]
}

resource "google_storage_bucket_iam_member" "delivery_artifacts_storage_admin" {
  for_each = var.env_cluster_membership_ids
  bucket   = module.delivery_artifacts[each.key].name
  role     = "roles/storage.admin"
  member   = google_service_account.cloud_deploy.member
}
