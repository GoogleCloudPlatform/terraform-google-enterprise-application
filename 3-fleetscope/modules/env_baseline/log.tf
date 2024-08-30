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

resource "google_gke_hub_feature" "fleet-o11y" {
  name     = "fleetobservability"
  project  = var.fleet_project_id
  location = "global"
  spec {
    fleetobservability {
      logging_config {
        default_config {
          mode = "COPY"
        }
        fleet_scope_logs_config {
          mode = "MOVE"
        }
      }
    }
  }

  depends_on = [
    google_gke_hub_feature.mesh_feature,
    google_project_iam_member.fleet_logging_viewaccessor
  ]
}

resource "google_project_iam_member" "fleet_logging_viewaccessor" {
  for_each = var.namespace_ids

  project = var.fleet_project_id
  role    = "roles/logging.viewAccessor"
  member  = "group:${each.value}"

  condition {
    title       = "Log bucket reader condition"
    description = "Grants logging.viewAccessor role"
    expression  = "resource.name == \"projects/${var.fleet_project_id}/locations/global/buckets/fleet-o11y-scope-${each.key}/views/fleet-o11y-scope-${each.key}-k8s_container\" || resource.name == \"projects/${var.fleet_project_id}/locations/global/buckets/fleet-o11y-scope-${each.key}/views/fleet-o11y-scope-${each.key}-k8s_pod\""
  }
}
