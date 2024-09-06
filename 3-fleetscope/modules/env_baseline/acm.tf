/**
 * Copyright 2024 Google LLC
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

data "google_project" "cluster_project" {
  project_id = var.cluster_project_id
}

resource "google_sourcerepo_repository" "acm_repo" {
  project = var.cluster_project_id
  name    = "eab-acm"
}

resource "google_service_account" "root_reconciler" {
  project                      = var.cluster_project_id
  account_id                   = "root-reconciler"
  display_name                 = "root-reconciler"
  create_ignore_already_exists = true
}

resource "google_project_iam_member" "root_reconciler" {
  project = var.cluster_project_id
  role    = "roles/source.reader"
  member  = "serviceAccount:${google_service_account.root_reconciler.email}"
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.root_reconciler.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.cluster_project_id}.svc.id.goog[config-management-system/root-reconciler]",
  ]
}

resource "google_gke_hub_feature" "acm_feature" {
  name     = "configmanagement"
  project  = var.cluster_project_id
  location = "global"
}

resource "google_gke_hub_feature_membership" "acm_feature_member" {
  for_each = toset(var.cluster_membership_ids)

  project  = var.cluster_project_id
  location = "global"

  feature             = google_gke_hub_feature.acm_feature.name
  membership          = regex(local.membership_re, each.key)[2]
  membership_location = regex(local.membership_re, each.key)[1]

  configmanagement {
    version = "1.18.0"
    config_sync {
      source_format = "unstructured"
      git {
        sync_repo                 = google_sourcerepo_repository.acm_repo.url
        secret_type               = "gcpserviceaccount"
        gcp_service_account_email = google_service_account.root_reconciler.email
      }
    }
  }

  depends_on = [
    google_gke_hub_feature.acm_feature
  ]
}

# Allow Services Accounts to create trace
resource "google_project_iam_binding" "acm_wi_trace_agent" {
  project = var.fleet_project_id

  role = "roles/cloudtrace.agent"
  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/default/sa/cymbal-bank", #TODO rename/move
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
  ]
}

# Allow Services Accounts to send metrics
resource "google_project_iam_binding" "acm_wi_metricWriter" {
  project = var.fleet_project_id

  role = "roles/monitoring.metricWriter"
  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/default/sa/cymbal-bank", #TODO rename/move
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
  ]
}
