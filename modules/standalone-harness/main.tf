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
  projects_re   = "projects/([^/]+)/"
  workerpool_id = var.workerpool_id == null ? module.private_workerpool[0].workerpool_id : var.workerpool_id

  default_services = [
    "accesscontextmanager.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "anthospolicycontroller.googleapis.com",
    "artifactregistry.googleapis.com",
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

  proxy_subnet = var.enable_proxy_subnet ? [{
    subnet_name           = "sb-proxy-only-${var.region}"
    subnet_ip             = "10.129.0.0/23"
    purpose               = "REGIONAL_MANAGED_PROXY"
    subnet_region         = var.region
    role                  = "ACTIVE"
    subnet_private_access = false
  }] : []

  services = distinct(concat(local.default_services, var.additional_services))
}

module "private_workerpool" {
  source = "../private_workerpool"
  count  = var.workerpool_id == null ? 1 : 0

  project_id = var.project_id
  region     = var.region
  network_id = var.network_id
  create_nat = var.create_nat

  private_workerpool_name = var.private_workerpool_name

  worker_range_ip = var.worker_range_ip

  enables_network_connection_and_peering_routes = var.enables_network_connection_and_peering_routes

  depends_on = [google_project_service.required_services, google_kms_crypto_key_iam_member.bucket_crypto_key, time_sleep.wait_access_level_propagation]
}

module "binary_autz" {
  source                      = "../binary-authz-build-image"
  project_id                  = var.project_id
  location                    = var.region
  binary_auth_image_version   = "v1.0"
  workerpool_id               = local.workerpool_id
  attestation_repository_name = var.attestation_repository_name
  bucket_logs_url             = var.logging_bucket != null ? "gs://${var.logging_bucket}" : null

  module_dependencies = concat([for s in google_project_service.required_services : s.id],
  var.build_image_module_dependencies)
}

module "cluster_network" {
  source                     = "../cluster_network"
  vpc_name                   = var.vpc_name
  project_id                 = var.project_id
  shared_vpc_host            = false
  private_service_connect_ip = var.private_service_connect_ip
  subnets = concat([{
    subnet_name           = "${var.vpc_name}-net-${var.region}"
    subnet_ip             = var.subnet_ip
    subnet_region         = var.region
    subnet_private_access = true
  }], local.proxy_subnet)

  secondary_ranges = {
    "${var.vpc_name}-net-${var.region}" = [
      {
        range_name    = "${var.vpc_name}-net-${var.region}-secondary-01"
        ip_cidr_range = var.secondary_ip_cidr_range_01
      },
      {
        range_name    = "${var.vpc_name}-net-${var.region}-secondary-02"
        ip_cidr_range = var.secondary_ip_cidr_range_02
      },
    ],
  }

  ingress_rules = [
    {
      name     = "fw-allow-health-check"
      priority = 1000
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
      allow = [
        {
          protocol = "tcp"
        }
      ]
    },
    {
      name     = "fw-allow-proxies"
      priority = 1000
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      source_ranges = ["10.129.0.0/23"]
      allow = [
        {
          protocol = "tcp"
        }
      ]
    }
  ]

  depends_on = [google_project_service.required_services]
}
