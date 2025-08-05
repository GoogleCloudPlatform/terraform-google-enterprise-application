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
    "roles/artifactregistry.admin",
    "roles/certificatemanager.owner",
    "roles/cloudbuild.builds.builder",
    "roles/cloudbuild.workerPoolOwner",
    "roles/clouddeploy.admin",
    "roles/clouddeploy.serviceAgent",
    "roles/cloudkms.admin",
    "roles/compute.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/container.admin",
    "roles/container.clusterAdmin",
    "roles/dns.admin",
    "roles/gkehub.editor",
    "roles/gkehub.scopeAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/logging.logWriter",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/source.admin",
    "roles/storage.admin",
    "roles/viewer",
  ]
}

resource "google_service_account" "int_test" {
  project                      = module.seed_project.project_id
  account_id                   = "ci-account"
  display_name                 = "ci-account"
  create_ignore_already_exists = true
}

resource "google_project_iam_member" "int_test_connection_admin" {
  project = module.seed_project.project_id
  role    = "roles/cloudbuild.connectionAdmin"
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_folder_iam_member" "int_test_connection_admin" {
  for_each = toset(["roles/resourcemanager.projectCreator", "roles/resourcemanager.folderCreator", "roles/owner", "roles/iam.serviceAccountTokenCreator", "roles/iam.serviceAccountUser", ])
  folder   = module.folder_seed.id
  role     = each.value
  member   = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_project_iam_member" "int_test" {
  for_each = toset(local.int_required_roles)

  project = module.seed_project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "organizationServiceAgent_role" {
  org_id = var.org_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "organization_xpn_role" {
  org_id = var.org_id
  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "orgPolicyAdmin_role" {
  org_id = var.org_id
  role   = "roles/orgpolicy.policyAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "policyAdmin_role" {
  org_id = var.org_id
  role   = "roles/accesscontextmanager.policyAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_service_account_key" "int_test" {
  service_account_id = google_service_account.int_test.id
}

resource "google_service_account_iam_member" "service_account_token_creator" {
  service_account_id = google_service_account.int_test.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.cloud_build_sa}"
}

resource "google_service_account_iam_member" "service_account_user" {
  service_account_id = google_service_account.int_test.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.cloud_build_sa}"
}

resource "google_billing_account_iam_member" "tf_billing_admin" {
  billing_account_id = var.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_project_iam_member" "cb_service_agent_role" {
  project = module.seed_project.project_id
  role    = "roles/cloudbuild.serviceAgent"
  member  = "serviceAccount:service-${module.seed_project.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "google_services_usage_consumer" {
  project = module.seed_project.project_id
  role    = "roles/compute.serviceAgent"
  member  = "serviceAccount:${module.seed_project.project_number}@cloudservices.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_engine_service_agent_role" {
  project = module.seed_project.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:service-${module.seed_project.project_number}@compute-system.iam.gserviceaccount.com"
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
