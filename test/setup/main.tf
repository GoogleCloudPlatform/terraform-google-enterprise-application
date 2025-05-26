/**
 * Copyright 2024-2025 Google LLC
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
  envs = (var.branch_name == "release-please--branches--main" || startswith(var.branch_name, "test-all/")) ? [
    "development",
    "nonproduction",
    "production",
  ] : ["development"]

  teams = setunion([
    "cb-frontend",
    "cb-accounts",
    "cb-ledger"],
    !var.single_project ? ["cymbalshops", "hpc-team-a", "hpc-team-b"] : []
  )

  index          = !var.single_project ? "multitenant" : "single"
  project_id     = [for i, value in merge(module.project, module.project_standalone) : value.project_id][0]
  project_number = [for i, value in merge(module.project, module.project_standalone) : value.project_number][0]
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

# Create mock seed folder
module "folder_seed" {
  source              = "terraform-google-modules/folders/google"
  version             = "~> 5.0"
  prefix              = random_string.prefix.result
  parent              = "folders/${var.folder_id}"
  names               = ["seed"]
  deletion_protection = false
}

data "google_organization" "org" {
  organization = var.org_id
}

# Create google groups
module "group" {
  for_each = toset(local.teams)
  source   = "terraform-google-modules/group/google"
  version  = "~> 0.7"

  id           = "${each.key}-${random_string.prefix.result}@${data.google_organization.org.domain}"
  display_name = "${each.key}-${random_string.prefix.result}"
  description  = "Group module test group for ${each.key}"
  domain       = data.google_organization.org.domain
}

module "logging_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "10.0.2"

  name          = "bkt-logging-${random_string.prefix.result}"
  project_id    = local.project_id
  location      = "us-central1"
  force_destroy = true

  versioning = true
  encryption = { default_kms_key_name = module.kms.keys["key"] }

  # Module does not support values not know before apply (member and role are used to create the index in for_each)
  # https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v10.0.2/modules/simple_bucket/main.tf#L122
  # iam_members = [
  #   {
  #     role   = "roles/storage.admin"
  #     member = "serviceAccount:${google_service_account.gitlab_vm.email}"
  #   },
  #   {
  #     role   = "roles/storage.admin"
  #     member = "serviceAccount:${google_service_account.int_test[local.index].email}"
  #   }
  # ]
}

resource "google_storage_bucket_iam_member" "logging_storage_admin" {
  for_each = { "admin_gl" : google_service_account.gitlab_vm.member, "admin_ci" : google_service_account.int_test[local.index].member }
  bucket   = module.logging_bucket.name
  role     = "roles/storage.admin"
  member   = each.value
}


data "google_storage_project_service_account" "ci_gcs_account" {
  project = local.project_id
}

data "google_storage_project_service_account" "gitlab_gcs_account" {
  project = module.gitlab_project.project_id
}

module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id     = local.project_id
  location       = "us-central1"
  keyring        = "kms-storage-buckets"
  keys           = ["key"]
  set_owners_for = ["key"]
  owners = [
    google_service_account.int_test[local.index].member
  ]
  set_encrypters_for = ["key"]
  encrypters         = ["${data.google_storage_project_service_account.ci_gcs_account.member},${data.google_storage_project_service_account.gitlab_gcs_account.member},${google_service_account.int_test[local.index].member}"]
  set_decrypters_for = ["key"]
  decrypters         = ["${data.google_storage_project_service_account.ci_gcs_account.member},${data.google_storage_project_service_account.gitlab_gcs_account.member},${google_service_account.int_test[local.index].member}"]
  prevent_destroy    = false
}
