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
  int_required_roles = [
    "roles/owner"
  ]
  standalone_required_roles = [
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.builder",
    "roles/clouddeploy.serviceAgent",
    "roles/clouddeploy.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/container.admin",
    "roles/gkehub.editor",
    "roles/gkehub.scopeAdmin",
    "roles/container.clusterAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/source.admin",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/viewer",
    "roles/iam.serviceAccountUser",
    "roles/privilegedaccessmanager.projectServiceAgent",
    "roles/logging.logWriter",
    "roles/source.admin"
  ]
}

resource "google_service_account" "int_test" {
  project                      = module.project.project_id
  account_id                   = "ci-account"
  display_name                 = "ci-account"
  create_ignore_already_exists = true
}

resource "google_project_iam_member" "int_test" {
  for_each = toset(local.int_required_roles)

  project = module.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_project_iam_member" "standalone_int_test" {
  for_each = toset(local.standalone_required_roles)

  project = module.project_standalone.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "organizationServiceAgent_role" {
  org_id = var.org_id
  role   = "roles/privilegedaccessmanager.organizationServiceAgent"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_service_account_key" "int_test" {
  service_account_id = google_service_account.int_test.id
}

resource "google_billing_account_iam_member" "tf_billing_user" {
  billing_account_id = var.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_project_iam_member" "cb_standalone_service_agent_role" {
  project = module.project_standalone.project_id
  role    = "roles/cloudbuild.serviceAgent"
  member  = "serviceAccount:service-${module.project_standalone.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [module.project_standalone]
}

resource "google_project_iam_member" "cb_service_agent_role" {
  project = module.project.project_id
  role    = "roles/cloudbuild.serviceAgent"
  member  = "serviceAccount:service-${module.project.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [module.project]
}
