# Copyright 2024 Google LLC
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

data "google_project" "environment" {
  project_id = var.project_id
}

resource "google_project_service" "artifactregistry_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "artifactregistry.googleapis.com"
}

# resource "google_project_service" "anthos_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "anthos.googleapis.com"
# }

# resource "google_project_service" "anthosconfigmanagement_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "anthosconfigmanagement.googleapis.com"
# }

resource "google_project_service" "cloudresourcemanager_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "compute.googleapis.com"
}

# resource "google_project_service" "connectgateway_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "connectgateway.googleapis.com"
# }

resource "google_project_service" "container_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "containerfilesystem_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "containerfilesystem.googleapis.com"
}

# resource "google_project_service" "containersecurity_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "containersecurity.googleapis.com"
# }

# resource "google_project_service" "gkeconnect_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "gkeconnect.googleapis.com"
# }

# resource "google_project_service" "gkehub_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = false
#   project                    = data.google_project.environment.project_id
#   service                    = "gkehub.googleapis.com"
# }

resource "google_project_service" "cloudquotas_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudquotas.googleapis.com"
}

resource "google_project_service" "iam_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "iam.googleapis.com"
}

resource "google_project_service" "serviceusage_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "serviceusage.googleapis.com"
}

# Vertex AI API's

resource "google_project_service" "aiplatform_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "aiplatform.googleapis.com"
}

resource "google_project_service" "notebooks_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "notebooks.googleapis.com"
}

resource "google_project_service" "servicenetworking_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "servicenetworking.googleapis.com"
}

resource "google_project_service" "parallelstore_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "parallelstore.googleapis.com"
}

resource "google_project_service" "cloudkms_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudkms.googleapis.com"
}

resource "google_project_service" "cloudbuild_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = data.google_project.environment.project_id
  service                    = "cloudbuild.googleapis.com"
}

resource "google_project_service" "bigquery_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = var.project_id
  service                    = "bigquery.googleapis.com"
}

resource "google_project_service" "pubsub_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = var.project_id
  service                    = "pubsub.googleapis.com"
}

resource "google_project_service" "sts_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false
  project                    = var.project_id
  service                    = "sts.googleapis.com"
}

# Log Analytics

resource "google_logging_project_bucket_config" "all_analytics_enabled_bucket" {
  count            = var.enable_log_analytics ? 1 : 0
  project          = data.google_project.environment.project_id
  location         = "global"
  enable_analytics = true
  bucket_id        = "_Default"
  lifecycle {
    ignore_changes = [project]
  }
}

resource "google_logging_linked_dataset" "all_logging_linked_dataset" {
  count       = var.enable_log_analytics ? 1 : 0
  link_id     = "all_logging_bq_link"
  bucket      = google_logging_project_bucket_config.all_analytics_enabled_bucket[0].id
  description = "Linked dataset"
}
