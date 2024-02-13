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
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_gke_hub_scope" "fleet-scope" {
  scope_id = "${var.scope_id}-${var.env}"
  project  = var.project_id
}

resource "google_gke_hub_namespace" "fleet-ns" {
  scope_namespace_id = "${var.namespace_id}-${var.env}"
  scope_id           = google_gke_hub_scope.fleet-scope.scope_id
  scope              = google_gke_hub_scope.fleet-scope.name
  project            = var.project_id
}

resource "google_gke_hub_membership_binding" "membership-binding" {
  for_each = toset(var.cluster_membership_ids)

  membership_binding_id = "${var.scope_id}-${var.env}-${random_string.suffix.result}"
  scope                 = google_gke_hub_scope.fleet-scope.name
  membership_id         = regex(local.membership_re, each.key)[2]
  location              = regex(local.membership_re, each.key)[1]
  project               = var.project_id
}
