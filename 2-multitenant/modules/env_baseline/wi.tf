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

#TODO: Remove or move to AppInfra after validating with @yliaog
resource "google_service_account" "app_service_accounts" {
  for_each = var.apps

  project                      = local.cluster_project_id
  account_id                   = each.key
  display_name                 = each.key
  create_ignore_already_exists = true
}

#TODO: Remove or move to AppInfra after validating with @yliaog
resource "google_service_account_iam_binding" "workload_identity" {
  for_each = google_service_account.app_service_accounts

  service_account_id = each.value.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${local.cluster_project_id}.svc.id.goog[accounts-${var.env}/${each.value.display_name}]",
    "serviceAccount:${local.cluster_project_id}.svc.id.goog[ledger-${var.env}/${each.value.display_name}]",
  ]

  depends_on = [
    module.gke.identity_namespace
  ]
}

