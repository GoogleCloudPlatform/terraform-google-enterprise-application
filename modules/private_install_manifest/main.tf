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
  repository_url   = "${data.google_artifact_registry_repository.k8s.location}-docker.pkg.dev/${data.google_artifact_registry_repository.k8s.project}/${data.google_artifact_registry_repository.k8s.repository_id}"
  applied_manifest = local_file.downloaded_file.content
}

data "http" "manifest_source" {
  url = var.url
}

resource "random_uuid" "uid" {
}

resource "google_artifact_registry_repository_iam_member" "cluster_service_accounts_reader" {
  for_each = toset(var.cluster_service_accounts)

  repository = data.google_artifact_registry_repository.k8s.repository_id
  project    = data.google_artifact_registry_repository.k8s.project
  location   = data.google_artifact_registry_repository.k8s.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

resource "local_file" "downloaded_file" {
  content  = replace(data.http.manifest_source.response_body, var.k8s_registry, local.repository_url)
  filename = "${path.module}/manifest-${random_uuid.uid.result}-${var.cluster_name}.yaml"

  depends_on = [google_artifact_registry_repository_iam_member.cluster_service_accounts_reader]
}

data "google_artifact_registry_repository" "k8s" {
  project       = var.project_id
  location      = var.region
  repository_id = "k8s"

  depends_on = [google_artifact_registry_repository.k8s]
}

resource "google_artifact_registry_repository" "k8s" {
  project       = var.project_id
  location      = var.region
  repository_id = "k8s"
  description   = "Kubernetes Registry Remote Repository"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  remote_repository_config {
    description = "Kubernetes Registry Remote Repository"
    docker_repository {
      custom_repository {
        uri = "https://${var.k8s_registry}"
      }
    }
  }
}

resource "google_artifact_registry_vpcsc_config" "vpcsc_config" {
  count        = var.vpcsc_policy == "ALLOW" ? 1 : 0
  provider     = google-beta
  location     = data.google_artifact_registry_repository.k8s.location
  project      = data.google_artifact_registry_repository.k8s.project
  vpcsc_policy = var.vpcsc_policy
}

module "kubectl" {
  source  = "terraform-google-modules/gcloud/google//modules/kubectl-fleet-wrapper"
  version = "~> 4.0"

  skip_download = true
  create_cmd_triggers = {
    "url" = var.url
  }

  membership_project_id   = var.cluster_project
  membership_name         = var.cluster_name
  membership_location     = var.cluster_region
  kubectl_create_command  = "kubectl apply --server-side -f ${path.module}/manifest-${random_uuid.uid.result}-${var.cluster_name}.yaml"
  kubectl_destroy_command = "timeout 300s kubectl delete -f ${path.module}/manifest-${random_uuid.uid.result}-${var.cluster_name}.yaml || exit 0"

  module_depends_on = [
    local_file.downloaded_file.filename,
  ]
}
