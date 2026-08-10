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

data "google_project" "admin_projects" {
  project_id = local.admin_project_id
}

resource "google_project_iam_member" "assign_permissions" {
  count   = var.workerpool_id != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_permissions_service_agent" {
  count   = var.workerpool_id != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${data.google_project.admin_projects.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "sd_viewer" {
  count   = var.workerpool_id != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/servicedirectory.viewer"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "access_network" {
  count   = var.workerpool_id != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/servicedirectory.pscAuthorizedService"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "time_sleep" "wait_roles_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.assign_permissions,
    google_project_iam_member.assign_permissions_service_agent,
    google_project_iam_member.sd_viewer,
    google_project_iam_member.access_network,
  ]
}
