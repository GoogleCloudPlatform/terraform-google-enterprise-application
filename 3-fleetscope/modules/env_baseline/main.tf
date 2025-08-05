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
  membership_re = "//gkehub.googleapis.com/projects/([^/]*)/locations/([^/]*)/memberships/([^/]*)$"

  scope_membership = { for idx, val in setproduct(keys(var.namespace_ids), var.cluster_membership_ids) :
  "${val[0]}-${idx}" => val }

  namespace_labels = { for ns, group in var.namespace_ids : ns => contains(var.disable_istio_on_namespaces, ns) ? {} : { "istio-injection" = "enabled" } }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_gke_hub_scope" "fleet-scope" {
  for_each = toset(keys(var.namespace_ids))

  scope_id = "${each.key}-${var.env}"
  project  = var.fleet_project_id
}

resource "google_gke_hub_namespace" "fleet-ns" {
  for_each = toset(keys(var.namespace_ids))

  scope_namespace_id = google_gke_hub_scope.fleet-scope[each.key].scope_id
  scope_id           = google_gke_hub_scope.fleet-scope[each.key].scope_id
  scope              = google_gke_hub_scope.fleet-scope[each.key].name
  project            = google_gke_hub_scope.fleet-scope[each.key].project

  labels           = local.namespace_labels[each.key]
  namespace_labels = local.namespace_labels[each.key]

  depends_on = [google_gke_hub_feature.mesh_feature]
}

resource "google_gke_hub_membership_binding" "membership-binding" {
  for_each = local.scope_membership

  membership_binding_id = "${google_gke_hub_scope.fleet-scope[each.value[0]].scope_id}-${random_string.suffix.result}"
  scope                 = google_gke_hub_scope.fleet-scope[each.value[0]].name
  membership_id         = regex(local.membership_re, each.value[1])[2]
  location              = regex(local.membership_re, each.value[1])[1]
  project               = google_gke_hub_scope.fleet-scope[each.value[0]].project
}

module "fleet_app_operator_permissions" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/fleet-app-operator-permissions"
  version = "~> 37.0"

  for_each = var.namespace_ids

  fleet_project_id = var.fleet_project_id
  scope_id         = google_gke_hub_scope.fleet-scope[each.key].scope_id
  groups           = [each.value]
  role             = "ADMIN"
}
