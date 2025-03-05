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
  repository_url = "${google_artifact_registry_repository.dockerhub.location}-docker.pkg.dev/${google_artifact_registry_repository.dockerhub.project}/${google_artifact_registry_repository.dockerhub.repository_id}"
}

resource "google_artifact_registry_repository_iam_member" "cluster_service_accounts_reader" {
  for_each = var.cluster_service_accounts

  repository = google_artifact_registry_repository.dockerhub.repository_id
  project    = google_artifact_registry_repository.dockerhub.project
  location   = google_artifact_registry_repository.dockerhub.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

resource "google_artifact_registry_repository" "dockerhub" {
  project       = var.infra_project
  location      = var.region
  repository_id = "dockerhub"
  description   = "Docker Hub Remote Repository"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  remote_repository_config {
    description = "Docker Hub Remote Repository"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  depends_on = [google_project_service.enable_apis]
}
