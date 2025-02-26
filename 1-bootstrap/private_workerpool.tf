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

module "project_workerpool" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name                     = "eab-private-workerpool"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  svpc_host_project_id     = var.workerpool_network_project_id
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  vpc_service_control_attach_dry_run = var.service_perimeter_name != null && var.service_perimeter_mode == "DRY_RUN"
  vpc_service_control_attach_enabled = var.service_perimeter_name != null && var.service_perimeter_mode == "ENFORCE"
  vpc_service_control_perimeter_name = var.service_perimeter_name
  vpc_service_control_sleep_duration = "2m"
  disable_services_on_destroy        = false

  activate_apis = [
    "accesscontextmanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "networkmanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

resource "google_cloudbuild_worker_pool" "pool" {
  name     = "cb-pool-bootstrap"
  project  = module.project_workerpool.project_id
  location = var.location
  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-4"
    no_external_ip = true
  }
  network_config {
    peered_network          = var.workerpool_network_id
    peered_network_ip_range = "/29"
  }
}

resource "google_org_policy_policy" "allowed_worker_pools" {
  name   = "${var.folder_id}/policies/cloudbuild.allowedWorkerPools"
  parent = var.folder_id

  spec {
    rules {
      values {
        allowed_values = [google_cloudbuild_worker_pool.pool.id]
      }
    }
  }
}
