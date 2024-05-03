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

resource "google_service_account" "bank_of_anthos" {
  project      = local.cluster_project_id
  account_id   = "bank-of-anthos"
  display_name = "bank-of-anthos"
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.bank_of_anthos.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${local.cluster_project_id}.svc.id.goog[accounts-${var.env}/bank-of-anthos]",
    "serviceAccount:${local.cluster_project_id}.svc.id.goog[ledger-${var.env}/bank-of-anthos]",
  ]

  depends_on = [
    module.gke.identity_namespace
  ]
}

