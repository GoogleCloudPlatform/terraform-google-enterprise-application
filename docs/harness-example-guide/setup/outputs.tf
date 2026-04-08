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

output "seed_project_id" {
  value = module.seed_project.project_id
}

output "cloud_build_sa" {
  value = var.cloud_build_sa
}

output "billing_account" {
  value = var.billing_account
}

output "org_id" {
  value = var.org_id
}

// **********************************************************************
// Logging bucket
// **********************************************************************

output "logging_bucket" {
  value = module.logging_bucket.name
}

// **********************************************************************
// KMS
// **********************************************************************

output "bucket_kms_key" {
  value = module.kms.keys["bucket"]
}

output "attestation_kms_key" {
  value = module.kms_attestor.keys["attestation"]
}

// **********************************************************************
// Workerpool
// **********************************************************************

output "workerpool_id" {
  value = module.private_workerpool.workerpool_id
}

// **********************************************************************
// VPC
// **********************************************************************

output "envs" {
  value = { for env, vpc in module.cluster_vpc : env => {
    org_id             = var.org_id
    folder_id          = module.folders.ids[env]
    billing_account    = var.billing_account
    network_project_id = vpc.project_id
    network_self_link  = vpc.network_self_link,
    subnets_self_links = [for sub in vpc.subnets_self_links : sub if strcontains(sub, "subnetworks/eab")],
  } }
}

output "common_folder_id" {
  value = module.folder_common.ids["common"]
}

output "attestation_evaluation_mode" {
  value = length(local.envs) == 1 ? "REQUIRE_ATTESTATION" : "ALWAYS_ALLOW"
}
