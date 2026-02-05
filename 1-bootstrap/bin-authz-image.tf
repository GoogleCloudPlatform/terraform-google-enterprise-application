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
  cmd_prompt = "gcloud builds submit binauthz-attestation/. --tag ${local.binary_auth_image_tag} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${module.build_logs.url} --worker-pool=${var.workerpool_id} || ( sleep 45 && gcloud builds submit --tag ${local.binary_auth_image_tag} --project=${var.project_id} --service-account=${google_service_account.builder.id} --gcs-log-dir=${module.build_logs.url}  --worker-pool=${var.workerpool_id}  )"

  binary_auth_image_version = "v1.1"
  binary_auth_image_tag     = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.attestation_image.name}/binauthz-attestation:${local.binary_auth_image_version}"
}

resource "google_artifact_registry_repository" "attestation_image" {
  project       = var.project_id
  location      = var.location
  repository_id = "binauthz-attestation"
  description   = "Binary Attestation Docker repository"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "builder_on_attestation_repo" {
  project    = google_artifact_registry_repository.attestation_image.project
  location   = google_artifact_registry_repository.attestation_image.location
  repository = google_artifact_registry_repository.attestation_image.name
  role       = "roles/artifactregistry.repoAdmin"
  member     = google_service_account.builder.member
}

module "build_binary_authz_image" {
  source            = "terraform-google-modules/gcloud/google"
  version           = "~> 4.0"
  upgrade           = false
  module_depends_on = [time_sleep.wait_iam_propagation]

  create_cmd_triggers = {
    "tag_version" = local.binary_auth_image_version
    "cmd_prompt"  = local.cmd_prompt
  }

  create_cmd_entrypoint = "bash"
  create_cmd_body       = "${local.cmd_prompt} || ( sleep 45 && ${local.cmd_prompt})"
}
