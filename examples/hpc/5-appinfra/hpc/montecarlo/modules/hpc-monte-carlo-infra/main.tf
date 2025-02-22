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

locals {
  docker_tag_version_terraform = "v1"
  teams_suffix                 = ["a", "b"]
}

resource "google_project_iam_member" "team_roles" {
  for_each = {
    for o in flatten([
      for team in local.teams_suffix : [
        for role in ["roles/storage.objectUser", "roles/pubsub.publisher", "roles/pubsub.viewer"] :
        {
          "team" : team,
          "role" : role
        }
      ]
    ]) :
    "${o.team}/${o.role}" => o
  }

  project = var.infra_project
  role    = each.value.role
  member  = "principalSet://iam.googleapis.com/projects/${var.cluster_project_number}/locations/global/workloadIdentityPools/${var.cluster_project}.svc.id.goog/namespace/hpc-team-${each.value.team}-${var.env}"
}

resource "google_project_service" "enable_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "notebooks.googleapis.com",
    "batch.googleapis.com",
    "pubsub.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com"
  ])
  project            = var.infra_project
  service            = each.key
  disable_on_destroy = false
}

data "google_compute_default_service_account" "default" {
  project = var.infra_project
}

resource "google_compute_network" "default" {
  name                    = "default"
  project                 = var.infra_project
  auto_create_subnetworks = true
}


// TODO: Define exactly where permissions below on fleet scope and fleet project should be assigned - maybe this should be a PR from the team to the 2-multitenant repo, so a platform engineer can approve the role grant
resource "google_project_iam_member" "compute_sa_roles" {
  for_each = toset([
    "roles/gkehub.connect",
    "roles/gkehub.viewer",
    "roles/gkehub.gatewayReader",
    "roles/gkehub.scopeEditorProjectLevel"
  ])
  role    = each.key
  project = var.cluster_project
  member  = data.google_compute_default_service_account.default.member
}

# TODO: Define exactly where to apply rbacrolebindings
module "fleet_app_operator_permissions" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/fleet-app-operator-permissions"
  version = "~> 36.0"

  for_each = toset(local.teams_suffix)

  fleet_project_id = var.cluster_project
  scope_id         = "hpc-team-${each.value}-${var.env}"
  users            = [data.google_compute_default_service_account.default.email]
  role             = "ADMIN"
}
