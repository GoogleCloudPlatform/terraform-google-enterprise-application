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
  namespaces            = [for k, v in google_gke_hub_scope.fleet-scope : v.scope_id]
  namespace_wide_access = [for namespace in local.namespaces : "principalSet://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/namespace/${namespace}"]
}

# Allow Services Accounts to create trace
resource "google_project_iam_binding" "acm_wi_trace_agent" {
  project = var.fleet_project_id

  role = "roles/cloudtrace.agent"
  members = concat([
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
    ],
    local.namespace_wide_access,
    var.additional_project_role_identities
  )

  depends_on = [google_gke_hub_feature_membership.acm_feature_member]
}

# Allow Services Accounts to send metrics
resource "google_project_iam_binding" "acm_wi_metricWriter" {
  project = var.fleet_project_id

  role = "roles/monitoring.metricWriter"
  members = concat([
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
    ],
    local.namespace_wide_access,
    var.additional_project_role_identities
  )
  depends_on = [google_gke_hub_feature_membership.acm_feature_member]
}
