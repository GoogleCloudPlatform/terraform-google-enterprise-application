# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  repository_prefix = "${var.repository_region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"

  keda_version = "2.18.2"

  keda_target_operator = "${local.repository_prefix}/keda"
  keda_target_adapter  = "${local.repository_prefix}/keda-metrics-apiserver"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_storage_bucket" "cloudbuild_keda" {
  project                     = var.project_id
  location                    = var.region
  name                        = "${var.project_id}-${var.region}-cloudbuild-keda-${random_string.suffix.id}"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "null_resource" "mirror_keda_images" {
  # Re-run this process if the KEDA version changes
  triggers = {
    version = local.keda_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Create a temporary directory for the build context
      mkdir -p keda_mirror_build
      mkdir -p keda_mirror_build_apiserver

      # --- BUILD KEDA OPERATOR ---
      # Create a simple Dockerfile that pulls the external image
      echo "FROM ghcr.io/kedacore/keda:${local.keda_version}" > keda_mirror_build/Dockerfile

      # Submit build to Cloud Build (Handles Pull -> Tag -> Push)
      gcloud builds submit \
        --project ${var.project_id} \
        --region ${var.region} \
        --gcs-source-staging-dir gs://${google_storage_bucket.cloudbuild_keda.id}/source/keda-operator \
        --gcs-log-dir gs://${google_storage_bucket.cloudbuild_keda.id}/logs/keda-operator \
        --tag "${local.keda_target_operator}:${local.keda_version}" \
        --tag "${local.keda_target_operator}:latest" \
        keda_mirror_build

      # --- BUILD KEDA ADAPTER ---
      # Update Dockerfile for the adapter image
      echo "FROM ghcr.io/kedacore/keda-metrics-apiserver:${local.keda_version}" > keda_mirror_build_apiserver/Dockerfile

      # Submit build to Cloud Build
      gcloud builds submit \
        --project ${var.project_id} \
        --region ${var.region} \
        --gcs-source-staging-dir gs://${google_storage_bucket.cloudbuild_keda.id}/source/keda-adapter \
        --gcs-log-dir gs://${google_storage_bucket.cloudbuild_keda.id}/logs/keda-adapter \
        --tag "${local.keda_target_adapter}:${local.keda_version}" \
        --tag "${local.keda_target_adapter}:latest" \
        keda_mirror_build_apiserver

      # Cleanup local temp directory
      rm -rf keda_mirror_build
      rm -rf keda_mirror_build_apiserver
    EOT
  }
}

data "google_artifact_registry_docker_image" "keda_operator" {
  depends_on = [null_resource.mirror_keda_images]

  project       = var.project_id
  location      = var.repository_region
  repository_id = var.repository_id
  image_name    = "keda"
}

data "google_artifact_registry_docker_image" "keda_api_server" {
  depends_on = [null_resource.mirror_keda_images]

  project       = var.project_id
  location      = var.repository_region
  repository_id = var.repository_id
  image_name    = "keda-metrics-apiserver"
}
