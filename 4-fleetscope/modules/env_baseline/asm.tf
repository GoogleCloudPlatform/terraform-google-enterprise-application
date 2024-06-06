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

resource "google_gke_hub_feature" "mesh_feature" {
  name     = "servicemesh"
  location = "global"
  project  = var.fleet_project_id
  fleet_default_member_config {
    mesh {
      management = "MANAGEMENT_AUTOMATIC"
    }
  }
}

resource "google_gke_hub_feature_membership" "mesh_feature_member" {
  project  = var.fleet_project_id
  location = "global"

  for_each = toset(var.cluster_membership_ids)

  feature             = google_gke_hub_feature.mesh_feature.name
  membership          = regex(local.membership_re, each.key)[2]
  membership_location = regex(local.membership_re, each.key)[1]

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_gke_hub_feature.mesh_feature,
    google_project_iam_member.cluster_service_agent_mesh
  ]
}

resource "google_project_service_identity" "fleet_meshconfig_sa" {
  provider = google-beta
  project  = var.fleet_project_id
  service  = "meshconfig.googleapis.com"
}

data "google_project" "fleet_project" {
  project_id = var.fleet_project_id
}

// Grant service mesh service identity permission to access the cluster and network project
resource "google_project_iam_member" "cluster_service_agent_mesh" {
  for_each = toset(distinct([var.cluster_project_id, var.network_project_id]))

  project = each.key
  role    = "roles/anthosservicemesh.serviceAgent"
  member  = "serviceAccount:service-${data.google_project.fleet_project.number}@gcp-sa-servicemesh.iam.gserviceaccount.com"
  depends_on = [
    google_project_service_identity.fleet_meshconfig_sa
  ]
}
