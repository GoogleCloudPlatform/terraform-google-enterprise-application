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

data "google_project" "project" {
  project_id = var.network_project_id
}

module "alloydb" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"

  cluster_id       = "cluster-${local.region}-psc-${var.env}"
  cluster_location = local.region
  project_id       = var.app_project_id
  cluster_initial_user = {
    user     = "admin",
    password = "admin"
  }

  psc_enabled                   = true
  psc_allowed_consumer_projects = [data.google_project.project.number]

  primary_instance = {
    instance_id        = "cluster-${local.region}-instance1-psc-${var.env}",
    require_connectors = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
  }

  read_pool_instance = [
    {
      instance_id        = "cluster-${local.region}-r1-psc-${var.env}"
      display_name       = "cluster-${local.region}-r1-psc-${var.env}"
      require_connectors = false
      ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }
  ]
}

resource "google_compute_network" "psc_vpc" {
  name    = "psc-endpoint-vpc-${var.env}"
  project = var.network_project_id
}

resource "google_compute_subnetwork" "psc_subnet" {
  project       = var.network_project_id
  name          = "psc-endpoint-subnet-${var.env}"
  ip_cidr_range = "10.2.0.0/16"
  region        = local.region
  network       = google_compute_network.psc_vpc.id
}

# Create psc endpoing using alloydb psc attachment.

resource "google_compute_address" "psc_consumer_address" {
  name    = "psc-consumer-address-${var.env}"
  project = var.network_project_id
  region  = local.region

  subnetwork   = google_compute_subnetwork.psc_subnet.name
  address_type = "INTERNAL"
  address      = "10.2.0.10"
}

resource "google_compute_forwarding_rule" "psc_fwd_rule_consumer" {
  name    = "psc-fwd-rule-consumer-endpoint-${var.env}"
  region  = local.region
  project = var.network_project_id

  target                  = module.alloydb.primary_instance.psc_instance_config[0].service_attachment_link
  load_balancing_scheme   = "" # need to override EXTERNAL default when target is a service attachment
  network                 = google_compute_network.psc_vpc.name
  ip_address              = google_compute_address.psc_consumer_address.id
  allow_psc_global_access = true
}

# Grant workload identity service account access to alloydb.

resource "google_project_iam_member" "bank_of_anthos" {
  project = var.app_project_id
  role    = "alloydb.admin"
  member  = "serviceAccount:bank-of-anthos@${var.cluster_project_id}.iam.gserviceaccount.com"
}
