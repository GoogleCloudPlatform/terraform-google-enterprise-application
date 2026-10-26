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

resource "google_service_account" "binauthz_builder" {
  count        = var.service_account_id == null ? 1 : 0
  project      = var.project_id
  account_id   = "sa-binauthz-builder"
  display_name = "Cloud Build Service Account for BinAuthz Attestation Image"
}

resource "google_project_iam_member" "binauthz_builder_roles" {
  for_each = var.service_account_id == null ? toset([
    "roles/logging.logWriter",
    "roles/storage.admin"
  ]) : []
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.binauthz_builder[0].email}"
}

locals {
  service_account_id_to_use = var.service_account_id != null ? var.service_account_id : google_service_account.binauthz_builder[0].id
  service_account_email = var.service_account_id != null ? (
    can(regex("@", var.service_account_id)) ? (
      can(regex("/", var.service_account_id)) ? split("/", var.service_account_id)[length(split("/", var.service_account_id)) - 1] : var.service_account_id
    ) : var.service_account_id
  ) : google_service_account.binauthz_builder[0].email

  bucket_logs_url       = var.bucket_logs_url != null ? "--gcs-log-dir=${var.bucket_logs_url}" : "--default-buckets-behavior=regional-user-owned-bucket"
  service_account       = "--service-account=${local.service_account_id_to_use}"
  workerpool_id         = var.workerpool_id != null ? "--worker-pool=${var.workerpool_id}" : ""
  cmd_prompt            = "gcloud builds submit ${path.module}/binauthz-attestation/. --tag ${local.binary_auth_image_tag} --project=${var.project_id}  ${local.bucket_logs_url} ${local.workerpool_id} ${local.service_account}"
  binary_auth_image_tag = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.attestation_image.name}/binauthz-attestation:${var.binary_auth_image_version}"
}

resource "google_artifact_registry_repository" "attestation_image" {
  project       = var.project_id
  location      = var.location
  repository_id = var.attestation_repository_name
  description   = "Binary Attestation Docker repository"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "builder_on_attestation_repo" {
  project    = google_artifact_registry_repository.attestation_image.project
  location   = google_artifact_registry_repository.attestation_image.location
  repository = google_artifact_registry_repository.attestation_image.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.service_account_email}"
}

module "build_binary_authz_image" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 4.0"
  upgrade = false

  create_cmd_triggers = {
    "cmd_prompt" = local.cmd_prompt
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = "${local.cmd_prompt} || ( sleep 45 && ${local.cmd_prompt})"

  module_depends_on = concat(
    var.module_dependencies,
    [google_artifact_registry_repository.attestation_image.id],
    [for r in google_project_iam_member.binauthz_builder_roles : r.id],
    [google_artifact_registry_repository_iam_member.builder_on_attestation_repo.id]
  )
}
