# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  membership_re = "projects/([^/]*)/locations/([^/]*)/memberships/([^/]*)$"
  envs          = keys(var.env_cluster_membership_ids)

  memberships     = flatten([for i in local.envs : var.env_cluster_membership_ids[i].cluster_membership_ids])
  memberships_map = { for i, item in local.memberships : (i) => item }
  gke_projects    = { for i, item in local.memberships : (i) => regex(local.membership_re, item)[0] }
}

resource "google_project_iam_member" "cloud_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"

  member = data.google_compute_default_service_account.compute_service_identity.member
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  member = data.google_compute_default_service_account.compute_service_identity.member
}

resource "google_project_iam_member" "cloudbuild_serviceAgent" {
  project = var.project_id
  role    = "roles/cloudbuild.serviceAgent"

  member = google_project_service_identity.cloudbuild_service_identity.member
}

resource "google_project_iam_member" "log_writer" {
  for_each = {
    "compute"      = data.google_compute_default_service_account.compute_service_identity.member,
    "cloud_deploy" = google_service_account.cloud_deploy.member,
    "cloud_build"  = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/logging.logWriter"

  member = each.value
}

resource "google_project_iam_member" "builder" {
  for_each = {
    "cloud_build_service" = google_service_account.cloud_deploy.member,
    "cloud_build"         = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"

  member = each.value
}

resource "google_project_iam_member" "gateway_editor" {
  for_each = {
    "cloud_deploy" = google_service_account.cloud_deploy.member,
    "cloud_build"  = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/gkehub.gatewayEditor"

  member = each.value
}

resource "google_project_iam_member" "gke_viewer" {
  for_each = {
    "cloud_deploy" = google_service_account.cloud_deploy.member,
    "cloud_build"  = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/gkehub.viewer"

  member = each.value
}

resource "google_project_iam_member" "cloud_deploy_releaser" {
  project = var.project_id
  role    = "roles/clouddeploy.releaser"

  member = google_service_account.cloud_build.member
}

resource "google_project_iam_member" "container_developer" {
  for_each = {
    "cloud_deploy" = google_service_account.cloud_deploy.member,
    "cloud_build"  = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/container.developer"

  member = each.value
}

resource "google_project_iam_member" "container_admin" {
  for_each = {
    "cloud_deploy" = google_service_account.cloud_deploy.member,
    "cloud_build"  = google_service_account.cloud_build.member,
  }
  project = var.project_id
  role    = "roles/container.admin"

  member = each.value
}

resource "google_project_iam_member" "cloudbuild_service_account" {
  for_each = {
    "cloud_deploy"     = google_service_account.cloud_deploy.member,
    "cloud_build"      = google_service_account.cloud_build.member,
    "cb_service_agent" = google_project_service_identity.cloudbuild_service_identity.member,
    "cd_service_agent" = google_project_service_identity.cloud_deploy_sa.member,
  }
  project = local.worker_pool_project
  role    = "roles/cloudbuild.builds.builder"

  member = each.value
}

resource "google_project_iam_member" "logging_writer" {
  for_each = {
    "cloud_deploy"     = google_service_account.cloud_deploy.member,
    "cloud_build"      = google_service_account.cloud_build.member,
    "service_agent"    = google_project_service_identity.cloudbuild_service_identity.member,
    "cd_service_agent" = google_project_service_identity.cloud_deploy_sa.member,
  }
  project = local.worker_pool_project
  role    = "roles/logging.logWriter"

  member = each.value
}

resource "google_project_iam_member" "bin_auth_policy_evaluator" {
  for_each = var.cluster_service_accounts
  project  = var.project_id
  role     = "roles/binaryauthorization.policyEvaluator"
  member   = each.value
}

// added to avoid overwriten of roles for each app service deploy service account, since GKE projects are shared between services
module "cb-gke-project-iam-bindings" {
  source     = "terraform-google-modules/iam/google//modules/member_iam"
  version    = "~> 8.0"
  for_each   = local.gke_projects
  project_id = each.value

  project_roles           = ["roles/container.admin", "roles/container.developer", "roles/gkehub.viewer", "roles/gkehub.gatewayEditor", "roles/cloudbuild.workerPoolUser", "roles/containeranalysis.notes.attacher"]
  prefix                  = "serviceAccount"
  service_account_address = google_service_account.cloud_build.email
}

module "deploy-gke-project-iam-bindings" {
  source     = "terraform-google-modules/iam/google//modules/member_iam"
  version    = "~> 8.0"
  for_each   = local.gke_projects
  project_id = each.value

  // TODO: grant less permissive roles and grant scope/team namespace specific high privileged roles
  project_roles           = ["roles/container.admin", "roles/container.developer", "roles/gkehub.viewer", "roles/gkehub.gatewayEditor"]
  prefix                  = "serviceAccount"
  service_account_address = google_service_account.cloud_deploy.email
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "bucket_crypto_key" {
  for_each = var.bucket_kms_key != null ? {
    "encrypt" : "roles/cloudkms.cryptoKeyEncrypter",
    "decrypt" : "roles/cloudkms.cryptoKeyDecrypter",
  } : {}
  crypto_key_id = var.bucket_kms_key
  role          = each.value
  member        = data.google_storage_project_service_account.gcs_account.member
}

resource "google_binary_authorization_attestor_iam_member" "member" {
  // attestor_id is only created by fleetscope step if the attestation_kms_key is != null,
  // to avoid the error `The "count" value depends on resource attributes that cannot be determined
  // until apply, so Terraform cannot predict how many instances will be created.` during single project examples
  // the code will only grant role to attestor_id if attestation_kms_key != null
  count    = var.attestation_kms_key != null ? 1 : 0
  project  = regex("projects/([^/]*)/", var.attestor_id)[0]
  attestor = regex("attestors/([^/]*)", var.attestor_id)[0]
  role     = "roles/binaryauthorization.attestorsVerifier"
  member   = google_service_account.cloud_build.member
}

resource "google_kms_crypto_key_iam_member" "attestor_crypto_key" {
  count         = var.attestation_kms_key != null ? 1 : 0
  crypto_key_id = var.attestation_kms_key
  role          = "roles/cloudkms.signerVerifier"
  member        = google_service_account.cloud_build.member
}

resource "google_artifact_registry_repository_iam_member" "builder_on_attestation_repo" {
  project    = regex("projects/([^/]*)/", var.binary_authorization_repository_id)[0]
  location   = regex("locations/([^/]*)/", var.binary_authorization_repository_id)[0]
  repository = regex("repositories/([^/]*)", var.binary_authorization_repository_id)[0]
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.cloud_build.member
}

resource "google_artifact_registry_repository_iam_member" "service_agent_on_attestation_repo" {
  project    = regex("projects/([^/]*)/", var.binary_authorization_repository_id)[0]
  location   = regex("locations/([^/]*)/", var.binary_authorization_repository_id)[0]
  repository = regex("repositories/([^/]*)", var.binary_authorization_repository_id)[0]
  role       = "roles/artifactregistry.reader"
  member     = google_project_service_identity.cloudbuild_service_identity.member
}

resource "time_sleep" "wait_cmek_iam_propagation" {
  create_duration = "60s"

  depends_on = [google_kms_crypto_key_iam_member.bucket_crypto_key]
}
