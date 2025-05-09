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

locals {
  is_zone  = can(regex("-[a-z]$", var.location))
  region   = local.is_zone ? regex("^(.*)-[a-z]$", var.location)[0] : var.location
  location = local.is_zone ? var.location : random_shuffle.zone.result[0]
}

data "google_project" "environment" {
  project_id = var.project_id
}

# Get available zones for the region
data "google_compute_zones" "available" {
  project = var.project_id
  region  = local.region
}

# Random zone selection
resource "random_shuffle" "zone" {
  input        = data.google_compute_zones.available.names
  result_count = 1
}

# Create Lustre instance
resource "google_lustre_instance" "lustre" {
  provider            = google-beta
  project             = var.project_id
  instance_id         = var.instance_id != null ? var.instance_id : "lustre-${var.location}"
  location            = var.location
  filesystem          = var.filesystem
  capacity_gib        = var.capacity_gib
  network             = var.network
  gke_support_enabled = var.gke_support_enabled

  timeouts {
    create = "120m"
    update = "120m"
    delete = "120m"
  }
}
