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
resource "google_storage_bucket" "build_cache" {
  project                     = var.project_id
  name                        = "build-cache-${var.service_name}-${data.google_project.project.number}"
  uniform_bucket_level_access = true
  location                    = var.region
  force_destroy               = var.buckets_force_destroy

  logging {
    log_bucket        = var.logging_bucket
    log_object_prefix = "build-${var.service_name}"
  }
}

resource "google_storage_bucket" "release_source_development" {
  project                     = var.project_id
  name                        = "release-source-development-${var.service_name}-${data.google_project.project.number}"
  uniform_bucket_level_access = true
  location                    = var.region
  force_destroy               = var.buckets_force_destroy
  logging {
    log_bucket        = var.logging_bucket
    log_object_prefix = "release-${var.service_name}"
  }
}

# Initialize cache with empty file
resource "google_storage_bucket_object" "cache" {
  bucket = google_storage_bucket.build_cache.name

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

# give CloudBuild SA access to skaffold cache
resource "google_storage_bucket_iam_member" "build_cache" {
  bucket = google_storage_bucket.build_cache.name

  member = "serviceAccount:${google_service_account.cloud_build.email}"
  role   = "roles/storage.admin"
}

# give CloudBuild SA access to write to source development bucket
resource "google_storage_bucket_iam_member" "release_source_development_admin" {
  bucket = google_storage_bucket.release_source_development.name

  member = "serviceAccount:${google_service_account.cloud_build.email}"
  role   = "roles/storage.admin"
}

# give CloudDeploy SA access to read from source development bucket
resource "google_storage_bucket_iam_member" "release_source_development_objectViewer" {
  bucket = google_storage_bucket.release_source_development.name

  member = "serviceAccount:${google_service_account.cloud_deploy.email}"
  role   = "roles/storage.objectViewer"
}
