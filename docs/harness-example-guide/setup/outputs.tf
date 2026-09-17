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
  description = "The Google Cloud project ID for deploying single-project examples."
}

output "project_number" {
  value       = module.seed_project.project_number
  description = "The Google Cloud project number."
}

output "region" {
  value       = var.region
  description = "The Google Cloud region for deployments."
}

output "billing_account" {
  value       = var.billing_account
  description = "The billing account ID."
}

output "org_id" {
  value       = var.org_id
  description = "The organization ID."
}

output "seed_folder_id" {
  value       = module.folder_seed.id
  description = "The folder ID created for the seed/harness project."
}

// **********************************************************************
// Logging bucket
// **********************************************************************

output "logging_bucket" {
  value       = module.logging_bucket.name
  description = "The GCS logging bucket name for Cloud Build and deployment logs."
}

// **********************************************************************
// KMS Keys
// **********************************************************************

output "bucket_kms_key" {
  value       = module.kms.keys["bucket"]
  description = "The KMS key ID for Cloud Storage bucket CMEK encryption."
}

output "attestation_kms_key" {
  value       = module.kms_attestor.keys["attestation"]
  description = "The KMS key ID for Binary Authorization asymmetric attestation signing."
}

output "state_kms_key" {
  value       = module.kms_tfstate.keys["state-key"]
  description = "The KMS key ID for Terraform state bucket CMEK encryption."
}

// **********************************************************************
// Terraform state bucket
// **********************************************************************

output "state_bucket" {
  value       = google_storage_bucket.terraform_state.name
  description = "The Cloud Storage bucket for Terraform remote state backend."
}

// **********************************************************************
// Workerpool & Network (Optional)
// **********************************************************************

output "workerpool_id" {
  value       = var.create_workerpool ? module.private_workerpool[0].workerpool_id : null
  description = "The ID of the pre-provisioned Cloud Build private worker pool (if create_workerpool is enabled)."
}

output "network_id" {
  value       = var.create_workerpool ? module.private_workerpool[0].network_id : null
  description = "The network ID/self-link of the pre-provisioned VPC (if create_workerpool is enabled)."
}
