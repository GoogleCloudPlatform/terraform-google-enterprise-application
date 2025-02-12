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

module "project_standalone" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  for_each = var.single_project ? { (local.index) = true } : {}

  name                     = "ci-enterprise-app-std"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"

  default_service_account = "KEEP"

  activate_api_identities = [
    {
      api   = "artifactregistry.googleapis.com",
      roles = ["roles/artifactregistry.serviceAgent"]
    },
    {
      api   = "compute.googleapis.com",
      roles = []
    },
    {
      api   = "container.googleapis.com",
      roles = ["roles/compute.networkUser", "roles/serviceusage.serviceUsageConsumer", "roles/container.serviceAgent"]
    },
    {
      api = "cloudbuild.googleapis.com",
      roles = [
        "roles/cloudbuild.builds.builder",
        "roles/cloudbuild.connectionAdmin",
      ]
    },
    {
      api   = "workflows.googleapis.com",
      roles = ["roles/workflows.serviceAgent"]
    },
    {
      api   = "config.googleapis.com",
      roles = ["roles/cloudconfig.serviceAgent"]
    }
  ]

  activate_apis = [
    "accesscontextmanager.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "apikeys.googleapis.com",
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
    "sourcerepo.googleapis.com",
    "sqladmin.googleapis.com",
    "storage-api.googleapis.com",
    "trafficdirector.googleapis.com",
  ]
}

resource "google_project_service_identity" "gke_identity_cluster_project" {
  provider = google-beta
  project  = local.project_id
  service  = "container.googleapis.com"
}
