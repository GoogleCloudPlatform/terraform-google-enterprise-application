/**
 * Copyright 2025 Google LLC
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
  cmd_prompt = "gcloud builds submit ./1-bootstrap/binauthz-attestation/. --tag ${local.binary_auth_image_tag} --project=${local.project_id} --service-account=${google_service_account.int_test[local.index].id} --gcs-log-dir=${module.logging_bucket.url} --worker-pool=${google_cloudbuild_worker_pool.pool.id} || ( sleep 45 && gcloud builds submit --tag ${local.binary_auth_image_tag} --project=${local.project_id} --service-account=${google_service_account.int_test[local.index].id} --gcs-log-dir=${module.logging_bucket.url}  --worker-pool=${google_cloudbuild_worker_pool.pool.id}  )"

  binary_auth_image_version = "v1"
  binary_auth_image_tag     = var.single_project ? "us-central1-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.attestation_image[local.index].name}/binauthz-attestation:${local.binary_auth_image_version}" : ""
}

resource "google_artifact_registry_repository" "attestation_image" {
  for_each      = var.single_project ? { (local.index) = true } : {}
  project       = local.project_id
  location      = "us-central1"
  repository_id = "binauthz-attestation"
  description   = "Binary Attestation Docker repository"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "builder_on_attestation_repo" {
  for_each   = var.single_project ? { (local.index) = true } : {}
  project    = google_artifact_registry_repository.attestation_image[local.index].project
  location   = google_artifact_registry_repository.attestation_image[local.index].location
  repository = google_artifact_registry_repository.attestation_image[local.index].name
  role       = "roles/artifactregistry.repoAdmin"
  member     = google_service_account.int_test[local.index].member
}

module "build_binary_authz_image" {
  for_each = var.single_project ? { (local.index) = true } : {}
  source   = "terraform-google-modules/gcloud/google"
  version  = "~> 3.5"
  upgrade  = false

  create_cmd_triggers = {
    "tag_version" = local.binary_auth_image_version
    "cmd_prompt"  = local.cmd_prompt
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = "${local.cmd_prompt} || ( sleep 45 && ${local.cmd_prompt})"
}
