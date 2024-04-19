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

module "balancereader" {
  source = "./balancereader"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}

module "contacts" {
  source = "./contacts"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}

module "frontend" {
  source = "./frontend"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}

module "ledgerwriter" {
  source = "./ledgerwriter"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}

module "transactionhistory" {
  source = "./transactionhistory"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}

module "userservice" {
  source = "./userservice"

  org_id               = var.org_id
  billing_account      = var.billing_account
  common_folder_id     = var.common_folder_id
  envs                 = var.envs
  bucket_prefix        = var.bucket_prefix
  location             = var.location
  trigger_location     = var.trigger_location
  bucket_force_destroy = var.bucket_force_destroy
  tf_apply_branches    = var.tf_apply_branches
}
