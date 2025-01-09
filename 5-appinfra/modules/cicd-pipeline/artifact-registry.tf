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

# create artifact registry for container images
resource "google_artifact_registry_repository" "container_registry" {
  repository_id = var.service_name
  location      = var.region
  format        = "DOCKER"
  description   = "${var.service_name} docker repository"
  project       = var.project_id

  depends_on = [
    module.enabled_google_apis
  ]
}

resource "google_artifact_registry_repository_iam_member" "member" {
  for_each = merge({
    cloud_deploy   = google_service_account.cloud_deploy.member,
    cloud_build_si = google_project_service_identity.cloudbuild_service_identity.member,
    compute        = data.google_compute_default_service_account.compute_service_identity.member,
  }, var.cluster_service_accounts)

  project    = var.project_id
  location   = var.region
  repository = var.service_name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.container_registry
  ]
}

# create artifact registry for DOCKER HUB
resource "google_artifact_registry_repository" "dockerhub_registry" {
  count         = var.create_artifact_registry_remote_dockerhub ? 1 : 0
  repository_id = "ar-dockerhub"
  location      = var.region
  format        = "DOCKER"
  description   = "${var.service_name} docker repository"
  project       = var.project_id
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "docker hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  depends_on = [
    module.enabled_google_apis
  ]
}

# create artifact registry for PYpi
resource "google_artifact_registry_repository" "python_registry" {
  count         = var.create_artifact_registry_remote_python ? 1 : 0
  repository_id = "ar-python"
  location      = var.region
  format        = "PYTHON"
  description   = "${var.service_name} docker repository"
  project       = var.project_id
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "PYPI"
    python_repository {
      public_repository = "PYPI"
    }
  }

  depends_on = [
    module.enabled_google_apis
  ]
}

resource "google_artifact_registry_repository_iam_member" "container_member" {
  for_each = merge({
    cloud_deploy   = google_service_account.cloud_deploy.member,
    cloud_build_si = google_project_service_identity.cloudbuild_service_identity.member,
    compute        = data.google_compute_default_service_account.compute_service_identity.member,
  }, var.cluster_service_accounts)

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.container_registry.name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.container_registry
  ]
}

resource "google_artifact_registry_repository_iam_member" "dockerhub_member" {
  for_each = var.create_artifact_registry_remote_dockerhub ? merge({
    cloud_deploy   = google_service_account.cloud_deploy.member,
    cloud_build_si = google_project_service_identity.cloudbuild_service_identity.member,
    compute        = data.google_compute_default_service_account.compute_service_identity.member,
  }, var.cluster_service_accounts) : {}

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.dockerhub_registry[0].name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.dockerhub_registry
  ]
}

resource "google_artifact_registry_repository_iam_member" "python_member" {
  for_each = var.create_artifact_registry_remote_python ? merge({
    cloud_deploy   = google_service_account.cloud_deploy.member,
    cloud_build_si = google_project_service_identity.cloudbuild_service_identity.member,
    compute        = data.google_compute_default_service_account.compute_service_identity.member,
  }, var.cluster_service_accounts) : {}

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.python_registry[0].name
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    module.enabled_google_apis,
    google_artifact_registry_repository.python_registry
  ]
}

resource "google_artifact_registry_vpcsc_config" "my-config" {
  count        = var.create_artifact_registry_remote_dockerhub || var.create_artifact_registry_remote_python ? 1 : 0
  provider     = google-beta
  project      = var.project_id
  location     = var.region
  vpcsc_policy = "ALLOW"
}
