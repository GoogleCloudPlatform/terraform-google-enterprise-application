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
  namespace_wide_access = { for i, namespace in local.namespaces : (i) => "principalSet://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/namespace/${namespace}" }
  namespace_wide_access = { for i, namespace in local.namespaces : (i) => "principalSet://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/namespace/${namespace}" }
}

# Allow Services Accounts to create trace
resource "google_project_iam_member" "acm_wi_trace_agent" {
  for_each = merge({
    "config"     = "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "gatekeeper" = "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
  }, local.namespace_wide_access, var.additional_project_role_identities)

  project = var.fleet_project_id
  role    = "roles/cloudtrace.agent"
  member  = each.value

  depends_on = [google_gke_hub_feature_membership.acm_feature_member]
}

# Allow Services Accounts to send metrics
resource "google_project_iam_member" "acm_wi_metricWriter" {
  for_each = merge({
    "config"     = "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/config-management-monitoring/sa/default",
    "gatekeeper" = "principal://iam.googleapis.com/projects/${data.google_project.cluster_project.number}/locations/global/workloadIdentityPools/${var.fleet_project_id}.svc.id.goog/subject/ns/gatekeeper-system/sa/gatekeeper-admin",
  }, local.namespace_wide_access, var.additional_project_role_identities)

  project    = var.fleet_project_id
  role       = "roles/monitoring.metricWriter"
  member     = each.value
  depends_on = [google_gke_hub_feature_membership.acm_feature_member]
}
