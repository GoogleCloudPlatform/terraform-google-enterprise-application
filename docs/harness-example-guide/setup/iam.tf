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

resource "google_project_iam_member" "cb_service_agent_role" {
  project = module.seed_project.project_id
  role    = "roles/cloudbuild.serviceAgent"
  member  = "serviceAccount:service-${module.seed_project.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "service_agent_role" {
  project = module.seed_project.project_id
  role    = "roles/compute.serviceAgent"
  member  = "serviceAccount:${module.seed_project.project_number}@cloudservices.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_engine_service_usage_role" {
  project = module.seed_project.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:service-${module.seed_project.project_number}@compute-system.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_engine_default_service_agent_role" {
  project = module.seed_project.project_id
  role    = "roles/compute.serviceAgent"
  member  = "serviceAccount:${module.seed_project.project_number}-compute@developer.gserviceaccount.com"
}
