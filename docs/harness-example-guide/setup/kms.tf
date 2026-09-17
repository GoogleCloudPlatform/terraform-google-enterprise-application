/**
 * Copyright 2026 Google LLC
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

data "google_storage_project_service_account" "ci_gcs_account" {
  project = module.seed_project.project_id
}

locals {
  cb_service_accounts = compact(concat(
    [
      "serviceAccount:service-${module.seed_project.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com",
      "serviceAccount:${module.seed_project.project_number}@cloudbuild.gserviceaccount.com"
    ],
    var.cloud_build_sa != null && var.cloud_build_sa != "" ? ["serviceAccount:${var.cloud_build_sa}"] : []
  ))
}

module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.1"

  project_id         = module.seed_project.project_id
  location           = var.region
  keyring            = "kms-bucket-encryption"
  keys               = ["bucket"]
  set_owners_for     = ["bucket"]
  owners             = local.cb_service_accounts
  set_encrypters_for = ["bucket"]
  encrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  set_decrypters_for = ["bucket"]
  decrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  prevent_destroy = var.kms_prevent_destroy
}

module "kms_tfstate" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.1"

  project_id         = module.seed_project.project_id
  location           = var.region
  keyring            = "kms-tfstate-encryption"
  keys               = ["state-key"]
  set_owners_for     = ["state-key"]
  owners             = local.cb_service_accounts
  set_encrypters_for = ["state-key"]
  encrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  set_decrypters_for = ["state-key"]
  decrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  prevent_destroy = var.kms_prevent_destroy
}

module "kms_attestor" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.1"

  project_id          = module.seed_project.project_id
  location            = var.region
  keyring             = "kms-attestation-sign"
  keys                = ["attestation"]
  set_owners_for      = ["attestation"]
  purpose             = "ASYMMETRIC_SIGN"
  key_algorithm       = "RSA_SIGN_PKCS1_4096_SHA512"
  key_rotation_period = null
  owners              = local.cb_service_accounts
  set_encrypters_for  = ["attestation"]
  encrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  set_decrypters_for = ["attestation"]
  decrypters = concat(
    [data.google_storage_project_service_account.ci_gcs_account.member],
    local.cb_service_accounts
  )
  prevent_destroy = var.kms_prevent_destroy
}
