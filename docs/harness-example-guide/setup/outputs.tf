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

output "project_id" {
  value       = module.seed_project.project_id
  description = "The ID of the seed project."
}

output "billing_account" {
  value       = var.billing_account
  description = "The billing account ID."
}

output "org_id" {
  value       = var.org_id
  description = "The organization ID."
}

// **********************************************************************
// Logging bucket
// **********************************************************************

output "logging_bucket" {
  value       = module.logging_bucket.name
  description = "The name of the logging bucket."
}

// **********************************************************************
// KMS
// **********************************************************************

output "bucket_kms_key" {
  value       = module.kms.keys["bucket"]
  description = "The KMS key for the bucket."
}

output "attestation_kms_key" {
  value       = module.kms_attestor.keys["attestation"]
  description = "The KMS key for attestation."
}

// **********************************************************************
// Workerpool
// **********************************************************************

output "workerpool_id" {
  value       = module.private_workerpool.workerpool_id
  description = "The ID of the private worker pool."
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
  description = "A map of environments to their respective VPC information."
}

output "common_folder_id" {
  value       = module.folder_common.ids["common"]
  description = "The ID of the common folder."
}

output "attestation_evaluation_mode" {
  value       = length(local.envs) == 1 ? "REQUIRE_ATTESTATION" : "ALWAYS_ALLOW"
  description = "The attestation evaluation mode, which is set to 'REQUIRE_ATTESTATION' if there is only one environment, and 'ALWAYS_ALLOW' otherwise."
}
