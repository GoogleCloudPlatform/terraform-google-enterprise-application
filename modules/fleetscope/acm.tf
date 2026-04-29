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

locals {
  cluster_membership_ids = { for k, v in var.cluster_membership_ids : k => v }
  use_csr                = var.config_sync_secret_type == "gcpserviceaccount"
}

data "google_project" "cluster_project" {
  project_id = var.cluster_project_id
}

resource "google_sourcerepo_repository" "acm_repo" {
  count = local.use_csr ? 1 : 0

  project                      = var.cluster_project_id
  name                         = "eab-acm"
  create_ignore_already_exists = true
}

resource "google_service_account" "root_reconciler" {
  count = local.use_csr ? 1 : 0

  project                      = var.cluster_project_id
  account_id                   = "root-reconciler"
  display_name                 = "root-reconciler"
  create_ignore_already_exists = true
}

resource "google_project_iam_member" "root_reconciler" {
  count = local.use_csr ? 1 : 0

  project = var.cluster_project_id
  role    = "roles/source.reader"
  member  = "serviceAccount:${google_service_account.root_reconciler[0].email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  count = local.use_csr ? 1 : 0

  service_account_id = google_service_account.root_reconciler[0].name

  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.cluster_project_id}.svc.id.goog[config-management-system/root-reconciler]"
}

resource "google_gke_hub_feature" "acm_feature" {
  name     = "configmanagement"
  project  = var.cluster_project_id
  location = "global"
}

resource "google_gke_hub_feature_membership" "acm_feature_member" {
  for_each = local.cluster_membership_ids

  project  = var.cluster_project_id
  location = "global"

  feature             = google_gke_hub_feature.acm_feature.name
  membership          = regex(local.membership_re, each.value)[2]
  membership_location = regex(local.membership_re, each.value)[1]

  configmanagement {
    version = "1.22.0"
    config_sync {
      enabled       = true
      source_format = "unstructured"
      git {
        sync_repo                 = local.use_csr ? google_sourcerepo_repository.acm_repo[0].url : var.config_sync_repository_url
        secret_type               = var.config_sync_secret_type
        gcp_service_account_email = local.use_csr ? google_service_account.root_reconciler[0].email : null
        policy_dir                = var.config_sync_policy_dir
        sync_branch               = var.config_sync_branch
      }
    }
  }

  depends_on = [
    google_gke_hub_feature.acm_feature
  ]
}
