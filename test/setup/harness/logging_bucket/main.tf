/**
 * Copyright 2025 Google LLC
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

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

module "logging_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 12.3"

  for_each = var.harness_project_ids

  name          = "bkt-logging-${each.value}-${random_string.prefix.result}"
  project_id    = each.value
  location      = var.region
  force_destroy = true

  versioning = true
  encryption = { default_kms_key_name = module.kms[each.key].keys["bucket"] }

  # Module does not support values not know before apply (member and role are used to create the index in for_each)
  # https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v10.0.2/modules/simple_bucket/main.tf#L122
  # iam_members = [
  #   {
  #     role   = "roles/storage.admin"
  #     member = "serviceAccount:${google_service_account.gitlab_vm.email}"
  #   },
  #   {
  #     role   = "roles/storage.admin"
  #     member = "serviceAccount:${google_service_account.int_test.email}"
  #   }
  # ]
}

resource "google_storage_bucket_iam_member" "logging_storage_admin" {
  for_each = var.harness_project_ids
  bucket   = module.logging_bucket[each.key].name
  role     = "roles/storage.admin"
  member   = "serviceAccount:${var.sa_email[each.key]}"
}

data "google_storage_project_service_account" "ci_gcs_account" {
  for_each = var.harness_project_ids
  project  = each.value
}

module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  for_each = var.harness_project_ids

  project_id     = each.value
  location       = var.region
  keyring        = "kms-bucket-encryption-${random_string.prefix.result}"
  keys           = ["bucket"]
  set_owners_for = ["bucket"]
  owners = [
    "serviceAccount:${var.sa_email[each.key]}",
  ]
  set_encrypters_for = ["bucket"]
  encrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account[each.key].member},${"serviceAccount:${var.sa_email[each.key]}"},serviceAccount:${var.cloud_build_sa}",
  ]
  set_decrypters_for = ["bucket"]
  decrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account[each.key].member},${"serviceAccount:${var.sa_email[each.key]}"},serviceAccount:${var.cloud_build_sa}",
  ]
  prevent_destroy = false
}

module "kms_attestor" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.1"

  for_each = var.harness_project_ids

  project_id          = each.value
  location            = var.region
  keyring             = "kms-attestation-sign-${random_string.prefix.result}"
  keys                = ["attestation"]
  set_owners_for      = ["attestation"]
  purpose             = "ASYMMETRIC_SIGN"
  key_algorithm       = "RSA_SIGN_PKCS1_4096_SHA512"
  key_rotation_period = null
  owners = [
    "serviceAccount:${var.sa_email[each.key]}",
  ]
  set_encrypters_for = ["attestation"]
  encrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account[each.key].member},${"serviceAccount:${var.sa_email[each.key]}"},serviceAccount:${var.cloud_build_sa}",
  ]
  set_decrypters_for = ["attestation"]
  decrypters = [
    "${data.google_storage_project_service_account.ci_gcs_account[each.key].member},${"serviceAccount:${var.sa_email[each.key]}"},serviceAccount:${var.cloud_build_sa}",
  ]
  prevent_destroy = false
}
