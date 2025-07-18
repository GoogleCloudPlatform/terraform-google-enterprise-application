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

module "private_workerpool_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name                     = "eab-private-workerpool"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.seed_folder_id
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  auto_create_network = true



  activate_apis = [
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "servicedirectory.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]
}

resource "time_sleep" "wait_api_propagation" {
  depends_on = [module.private_workerpool_project]

  create_duration = "60s"
}


resource "google_compute_global_address" "worker_range" {
  project       = module.private_workerpool_project.project_id
  name          = "worker-pool-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.3.3.0"
  prefix_length = 24
  network       = module.vpc.network_name

  depends_on = [time_sleep.wait_api_propagation]
}

resource "google_service_networking_connection" "gitlab_worker_pool_conn" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range.name]
  depends_on              = [google_project_service.servicenetworking, module.private_workerpool_project]
}

resource "google_project_service" "servicenetworking" {
  project            = module.private_workerpool_project.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloudbuild_worker_pool" "pool" {
  name     = "cb-pool"
  project  = module.private_workerpool_project.project_id
  location = var.workpool_region
  worker_config {
    disk_size_gb   = 100
    machine_type   = var.workerpool_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network          = module.vpc.network_id
    peered_network_ip_range = "/24"
  }

  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn, module.private_workerpool_project]
}

resource "time_sleep" "wait_service_network_peering" {
  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn]

  create_duration = "30s"
}
