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
  expanded_environment_with_service_accounts = flatten(
    [for key, email in local.cb_service_accounts_emails :
      [for fields in values(var.envs) :
        {
          multitenant_pipeline = key
          email                = email
          network_project_id   = fields.network_project_id
          billing_account      = fields.billing_account
          folder_id            = fields.folder_id
          org_id               = fields.org_id
        }
      ]
    ]
  )
}

# IAM Bindings for Google Service Accounts
# These resources assign specific roles to Cloud Build service accounts.

resource "google_service_account_iam_member" "account_access" {
  for_each = module.tf_cloudbuild_workspace

  service_account_id = each.value.cloudbuild_sa
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${reverse(split("/", each.value.cloudbuild_sa))[0]}"
}

resource "google_service_account_iam_member" "token_creator" {
  for_each = module.tf_cloudbuild_workspace

  service_account_id = each.value.cloudbuild_sa
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${reverse(split("/", each.value.cloudbuild_sa))[0]}"
}

# Viewer Role for Bootstrap Project
# This resource grants view access to service accounts in the bootstrap project.

resource "google_project_iam_member" "bootstrap_project_viewer" {
  for_each = local.cb_service_accounts_emails

  role    = "roles/viewer"
  member  = "serviceAccount:${each.value}"
  project = var.project_id
}

# Billing Account IAM Bindings
# This resource assigns the 'billing.user' role to service accounts for billing purposes.

resource "google_billing_account_iam_member" "billing_user" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role               = "roles/billing.user"
  member             = "serviceAccount:${each.value.email}"
  billing_account_id = each.value.billing_account
}

# Folder-Level IAM Bindings
# These resources assign roles to service accounts at the folder level.

resource "google_folder_iam_member" "project_creator" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "gkehub_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role   = "roles/gkehub.admin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "env_folder_projectIamAdmin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role   = "roles/resourcemanager.projectIamAdmin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "env_folder_service_account_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role   = "roles/iam.serviceAccountAdmin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "env_folder_source_repository_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" || obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/source.admin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "env_folder_artifactregistry_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" || obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/artifactregistry.admin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "containeranalysis_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" })

  role   = "roles/containeranalysis.admin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "binaryauth_attestor_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" })

  role   = "roles/binaryauthorization.attestorsAdmin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "binaryauth_policy_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" })

  role   = "roles/binaryauthorization.policyAdmin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_folder_iam_member" "xpn_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline != "fleetscope" })

  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${each.value.email}"
  folder = each.value.folder_id
}

resource "google_organization_iam_member" "xpn_admin" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline != "fleetscope" })

  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${each.value.email}"
  org_id = each.value.org_id
}

resource "google_project_iam_member" "network_project_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })

  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${each.value.email}"
  project = each.value.network_project_id
}

resource "google_project_iam_member" "network_user" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "multitenant" })

  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${each.value.email}"
  project = each.value.network_project_id
}

resource "google_project_iam_member" "self_kms_admin_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if var.bucket_kms_key == null })

  role    = "roles/cloudkms.admin"
  member  = "serviceAccount:${each.value.email}"
  project = var.project_id
}

resource "google_project_iam_member" "self_kms_encrypter_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if var.bucket_kms_key == null })

  role    = "roles/cloudkms.cryptoKeyEncrypter"
  member  = "serviceAccount:${each.value.email}"
  project = var.project_id
}

resource "google_project_iam_member" "self_kms_decrypter_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if var.bucket_kms_key == null })

  role    = "roles/cloudkms.cryptoKeyDecrypter"
  member  = "serviceAccount:${each.value.email}"
  project = var.project_id
}

resource "google_project_iam_member" "kms_sign" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "fleetscope" && var.attestation_kms_project != null })

  role    = "roles/cloudkms.signerVerifier"
  member  = "serviceAccount:${each.value.email}"
  project = var.attestation_kms_project
}

resource "google_folder_iam_member" "app_factory_foldereditor" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/resourcemanager.folderEditor"
  member = "serviceAccount:${each.value.email}"
  folder = var.common_folder_id
}

resource "google_folder_iam_member" "app_factory_folder_creator" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/resourcemanager.folderCreator"
  member = "serviceAccount:${each.value.email}"
  folder = var.common_folder_id
}

resource "google_folder_iam_member" "app_factory_project_creator" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${each.value.email}"
  folder = var.common_folder_id
}

// needed by terraform-vet to get parent folder
resource "google_organization_iam_member" "app_factory_folder_viewer" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })
  role     = "roles/resourcemanager.folderViewer"
  org_id   = var.org_id
  member   = "serviceAccount:${each.value.email}"
}

resource "google_project_iam_member" "project_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })

  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${each.value.email}"
  project = local.worker_pool_project
}

resource "google_project_iam_member" "secret_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" && var.cloudbuildv2_repository_config.secret_project_id != null })

  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${each.value.email}"
  project = var.cloudbuildv2_repository_config.secret_project_id
}

resource "google_project_iam_member" "kms_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" && var.bucket_kms_key != null })

  role    = "roles/cloudkms.admin"
  member  = "serviceAccount:${each.value.email}"
  project = local.kms_project
}

resource "google_project_iam_member" "cloud_build_worker_pool_user" {
  for_each = local.cb_service_accounts_emails

  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${each.value}"
  project = local.worker_pool_project
}

resource "google_organization_iam_member" "policyAdmin_role" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj })
  role     = "roles/accesscontextmanager.policyAdmin"
  org_id   = var.org_id
  member   = "serviceAccount:${each.value.email}"
}

resource "google_organization_iam_member" "org_iam_member" {
  for_each = tomap({ for i, obj in local.expanded_environment_with_service_accounts : i => obj if obj.multitenant_pipeline == "applicationfactory" })

  role   = "roles/resourcemanager.organizationAdmin"
  member = "serviceAccount:${each.value.email}"
  org_id = var.org_id
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
