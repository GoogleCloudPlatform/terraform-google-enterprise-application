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

resource "google_project_iam_member" "int_test_connection_admin" {
  project = var.seed_project_id
  role    = "roles/cloudbuild.connectionAdmin"
  member  = "serviceAccount:${var.sa_email}"
}

resource "google_project_iam_member" "int_test_vpc" {
  for_each = module.vpc_project

  project = each.value.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${var.sa_email}"
}

resource "google_project_iam_member" "int_test_iam" {
  for_each = module.vpc_project

  project = each.value.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${var.sa_email}"
}
