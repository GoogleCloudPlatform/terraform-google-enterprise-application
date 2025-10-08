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

# GCS bucket used as skaffold build cache
module "build_cache" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 11.0"

  name              = "${var.bucket_prefix}-build-cache-${var.service_name}-${data.google_project.project.number}"
  project_id        = var.project_id
  location          = var.region
  log_bucket        = var.logging_bucket
  log_object_prefix = "build-${var.project_id}"

  force_destroy = var.buckets_force_destroy

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
  #   member = google_service_account.cloud_build.member
  # }]

  depends_on = [google_kms_crypto_key_iam_member.bucket_crypto_key]
}

resource "google_storage_bucket_iam_member" "build_cache_storage_admin" {
  bucket = module.build_cache.name
  role   = "roles/storage.admin"
  member = google_service_account.cloud_build.member
}

module "release_source_development" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 11.0"

  name              = "${var.bucket_prefix}-release-source-development-${var.service_name}-${data.google_project.project.number}"
  project_id        = var.project_id
  location          = var.region
  log_bucket        = var.logging_bucket
  log_object_prefix = "release-${var.project_id}"
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
  #   member = google_service_account.cloud_build.member
  #   },
  #   {
  #     member = google_service_account.cloud_deploy.member
  #     role   = "roles/storage.objectViewer"
  # }]

  depends_on = [time_sleep.wait_cmek_iam_propagation]
}

resource "google_storage_bucket_iam_member" "release_source_development_storage_admin" {
  bucket = module.release_source_development.name
  role   = "roles/storage.admin"
  member = google_service_account.cloud_build.member
}

resource "google_storage_bucket_iam_member" "release_source_development_storage_object_viewer" {
  bucket = module.release_source_development.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.cloud_deploy.member
}

# Initialize cache with empty file
resource "google_storage_bucket_object" "cache" {
  bucket = module.build_cache.name

  name    = local.cache_filename
  content = " "

  lifecycle {
    # do not reset cache when running terraform
    ignore_changes = [
      content,
      detect_md5hash
    ]
  }
}
