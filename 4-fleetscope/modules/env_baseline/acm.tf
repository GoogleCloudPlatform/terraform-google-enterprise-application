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

resource "google_sourcerepo_repository" "acm_repo" {
  project = var.fleet_project_id
  name    = "eab-acm"
}

resource "google_service_account" "root_reconciler" {
  project      = var.fleet_project_id
  account_id   = "root-reconciler"
  display_name = "root-reconciler"
}

resource "google_project_iam_member" "root_reconciler" {
  project = var.fleet_project_id
  role    = "roles/source.reader"
  member  = "serviceAccount:${google_service_account.root_reconciler.email}"
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.root_reconciler.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.fleet_project_id}.svc.id.goog[config-management-system/root-reconciler]",
  ]
}

resource "google_gke_hub_feature" "acm_feature" {
  name     = "configmanagement"
  project  = var.fleet_project_id
  location = "global"
}

resource "google_gke_hub_feature_membership" "acm_feature_member" {
  for_each = toset(var.cluster_membership_ids)

  project  = var.fleet_project_id
  location = "global"

  feature             = google_gke_hub_feature.acm_feature.name
  membership          = regex(local.membership_re, each.key)[2]
  membership_location = regex(local.membership_re, each.key)[1]

  configmanagement {
    version = "1.17.2"
    config_sync {
      source_format = "unstructured"
      git {
        sync_repo                 = google_sourcerepo_repository.acm_repo.url
        secret_type               = "gcpserviceaccount"
        gcp_service_account_email = google_service_account.root_reconciler.email
      }
    }
    policy_controller {
      enabled                    = true
      template_library_installed = true
      referential_rules_enabled  = true
    }
  }

  depends_on = [
    google_gke_hub_feature.acm_feature
  ]
}
