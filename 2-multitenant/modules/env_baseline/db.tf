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

# CloudSQL Postgres instance
module "cloudsql" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version = "~> 20.0"

  for_each = data.google_compute_subnetwork.default

  project_id = local.cluster_project_id
  region     = each.value.region

  name                = "db-${each.value.region}-${var.env}"
  database_version    = "POSTGRES_14"
  enable_default_db   = false
  tier                = "db-custom-1-3840"
  deletion_protection = false
  availability_type   = "REGIONAL"

  additional_databases = [
    {
      name      = "accounts-db"
      charset   = ""
      collation = ""
    },
    {
      name      = "ledger-db"
      charset   = ""
      collation = ""
    }
  ]
  user_name     = "admin"
  user_password = "admin" # this is a security risk - do not do this for real world use-cases!
}

resource "google_service_account" "bank_of_anthos" {
  project      = local.cluster_project_id
  account_id   = "bank-of-anthos"
  display_name = "bank-of-anthos"
}

resource "google_project_iam_member" "bank_of_anthos" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = local.cluster_project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.bank_of_anthos.email}"
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

