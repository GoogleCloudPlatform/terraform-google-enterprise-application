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

locals {
  fleet_membership_re = "//gkehub.googleapis.com/(.*)$"
}

resource "google_gke_hub_feature" "mci" {
  name     = "multiclusteringress"
  location = "global"
  project  = var.fleet_project_id
  spec {
    multiclusteringress {
      config_membership = regex(local.fleet_membership_re, var.cluster_membership_ids[0])[0]
    }
  }
}

resource "google_gke_hub_feature" "mcs" {
  name     = "multiclusterservicediscovery"
  location = "global"
  project  = var.fleet_project_id
}

resource "google_project_service_identity" "fleet_mci_sa" {
  provider = google-beta
  project  = var.fleet_project_id
  service  = "multiclusteringress.googleapis.com"
}

// Grant IAM permissions for the Gateway controller in the fleet
resource "google_project_iam_member" "cluster_admin_mci" {
  project = var.cluster_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_project_service_identity.fleet_mci_sa.email}"
}

resource "google_project_service_identity" "fleet_mcs_sa" {
  provider = google-beta
  project  = var.fleet_project_id
  service  = "multiclusterservicediscovery.googleapis.com"
}

// Grant MCS service account access to the network project
resource "google_project_iam_member" "network_service_agent_mcs" {
  project = var.network_project_id
  role    = "roles/multiclusterservicediscovery.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.fleet_mcs_sa.email}"
}

// Grant MCS controller service account access to the cluster project
resource "google_project_iam_member" "cluster_network_viewer_mcs" {
  for_each = toset(["roles/compute.networkViewer", "roles/trafficdirector.client"])
  project  = var.cluster_project_id
  role     = each.key
  member   = "serviceAccount:${var.cluster_project_id}.svc.id.goog[gke-mcs/gke-mcs-importer]"
}
