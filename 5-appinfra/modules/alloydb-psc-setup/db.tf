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

locals {
  region = var.cluster_regions[0]
}

# Create alloydb cluster and instance.

data "google_project" "network_project" {
  project_id = var.network_project_id
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "alloydb" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"

  cluster_id       = "cluster-${local.region}-psc-${var.env}"
  cluster_location = local.region
  project_id       = var.app_project_id
  cluster_initial_user = {
    user     = "admin"
    password = random_password.password.result
  }

  psc_enabled                   = true
  psc_allowed_consumer_projects = [data.google_project.network_project.number]

  primary_instance = {
    instance_id        = "cluster-${local.region}-instance1-psc-${var.env}",
    require_connectors = false
    ssl_mode           = "ENCRYPTED_ONLY"
  }

  read_pool_instance = [
    {
      instance_id        = "cluster-${local.region}-r1-psc-${var.env}"
      display_name       = "cluster-${local.region}-r1-psc-${var.env}"
      require_connectors = false
      ssl_mode           = "ENCRYPTED_ONLY"
    }
  ]
}

resource "google_compute_forwarding_rule" "psc_fwd_rule_consumer" {
  name    = "psc-fwd-rule-consumer-endpoint-${var.env}"
  region  = local.region
  project = var.network_project_id

  target                  = module.alloydb.primary_instance.psc_instance_config[0].service_attachment_link
  load_balancing_scheme   = "" # need to override EXTERNAL default when target is a service attachment
  network                 = var.network_name
  ip_address              = var.psc_consumer_fwd_rule_ip
  allow_psc_global_access = true
}

# Grant workload identity service account access to alloydb.
resource "google_project_iam_member" "alloydb_admin" {
  project = var.app_project_id
  role    = "roles/alloydb.admin"
  member  = var.workload_identity_principal
}
