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

  for_each = toset(var.cluster_regions)

  project_id = var.app_project_id
  region     = each.value

  name                = "${var.db_name}-${each.value}-${var.env}"
  database_version    = "POSTGRES_14"
  enable_default_db   = false
  tier                = "db-custom-1-3840"
  deletion_protection = false
  availability_type   = "REGIONAL"

  ip_configuration = {
    ipv4_enabled                  = false
    psc_enabled                   = true
    psc_allowed_consumer_projects = [var.cluster_project_id]
  }

  additional_databases = [
    {
      name      = var.db_name
      charset   = ""
      collation = ""
    },
  ]
  user_name     = "admin"
  user_password = "admin" # this is a security risk - do not do this for real world use-cases!
}

resource "google_project_iam_member" "bank_of_anthos" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
  project  = var.app_project_id
  role     = each.value
  member   = "serviceAccount:bank-of-anthos@${var.cluster_project_id}.iam.gserviceaccount.com"
}

