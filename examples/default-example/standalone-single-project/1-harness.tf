/**
 * Copyright 2026 Google LLC
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

locals {
  workerpool_project_id         = var.workerpool_id != null ? regex(local.projects_re, var.workerpool_id)[0] : var.project_id
  workerpool_id                 = var.workerpool_id == null ? module.private_workerpool[0].workerpool_id : var.workerpool_id
  workerpool_network_project_id = var.network_id != null ? regex(local.projects_re, var.network_id)[0] : local.network_project_id

  services = [
    "accesscontextmanager.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "apikeys.googleapis.com",
    "binaryauthorization.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "mesh.googleapis.com",
    "monitoring.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "networkmanagement.googleapis.com",
    "secretmanager.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "storage-api.googleapis.com",
    "trafficdirector.googleapis.com",
  ]
}

resource "google_project_service" "required_services" {
  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value
}

module "private_workerpool" {
  source = "../../../modules/private_workerpool"
  count  = var.workerpool_id == null ? 1 : 0
   
  project_id = var.project_id
  region     = var.region
  network_id = var.network_id
  create_nat = var.create_nat

  enables_network_connection_and_peering_routes = var.enables_network_connection_and_peering_routes

  depends_on = [ google_project_service.required_services ]
}

module "binary_autz" {
  source                    = "../../../modules/binary-authz-build-image"
  project_id                = var.project_id
  location                  = var.region
  binary_auth_image_version = "v1.0"
  workerpool_id             = local.workerpool_id
  bucket_logs_url           = var.logging_bucket != null ? "gs://${var.logging_bucket}" : null
  depends_on = [ google_project_service.required_services ]
}

module "cluster_network" {
  source          = "../../../modules/cluster_network"
  vpc_name        = "eab-cluster"
  project_id      = var.project_id
  region          = var.region
  shared_vpc_host = false
  subnets = [
    {
      subnet_name           = "eab-cluster-net-${var.region}"
      subnet_ip             = "10.1.20.0/24"
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    "eab-cluster-net-${var.region}" = [
      {
        range_name    = "eab-cluster-net-${var.region}-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-cluster-net-${var.region}-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
    ],
  }
  depends_on = [ google_project_service.required_services ]
}
