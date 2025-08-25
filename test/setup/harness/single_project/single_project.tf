/**
 * Copyright 2025 Google LLC
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

resource "google_project_service_identity" "gke_identity_cluster_project" {
  provider = google-beta
  project  = var.seed_project_id
  service  = "container.googleapis.com"
}

data "google_project" "seed_project" {
  project_id = var.seed_project_id
}

module "single_project_vpc" {
  source = "../../modules/cluster_network"

  project_id      = var.seed_project_id
  vpc_name        = "cluster-vpc"
  shared_vpc_host = false

  subnets = [
    {
      subnet_name           = "eab-cluster-net-us-central1"
      subnet_ip             = "10.1.20.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    "eab-cluster-net-us-central1" = [
      {
        range_name    = "eab-cluster-net-us-central1-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-cluster-net-us-central1-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ],
  }
}
