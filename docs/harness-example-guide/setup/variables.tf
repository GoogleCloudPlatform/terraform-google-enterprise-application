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

variable "org_id" {
  description = "The numeric Google Cloud Organization ID."
  type        = string
}

variable "folder_id" {
  description = "The folder ID where the harness seed folder and project will be created."
  type        = string
}

variable "billing_account" {
  description = "The Google Cloud Billing Account ID (e.g., XXXXXX-YYYYYY-ZZZZZZ)."
  type        = string
}

variable "cloud_build_sa" {
  description = "Optional Cloud Build Service Account email to be granted KMS Encrypt/Decrypt and Attestation roles. If empty, the project default Cloud Build service account will be used."
  type        = string
  default     = ""
}

variable "region" {
  description = "The Google Cloud region for KMS, Logging bucket, tfstate bucket, and worker pools."
  type        = string
  default     = "us-central1"
}

variable "create_workerpool" {
  description = "Whether to pre-provision a dedicated Cloud Build Private Worker Pool with NAT VM. If false, single-project examples provision their own worker pools via standalone-harness."
  type        = bool
  default     = false
}

variable "workerpool_machine_type" {
  description = "The machine type for the Cloud Build Private Worker Pool."
  type        = string
  default     = "e2-standard-4"
}

variable "workerpool_peering_address" {
  description = "The internal IP address for the Cloud Build Private Worker Pool VPC peering range (e.g., 10.3.3.0)."
  type        = string
  default     = "10.3.3.0"
}

variable "workerpool_nat_subnet_ip" {
  description = "The CIDR block for the worker pool NAT proxy subnet (e.g., 10.1.1.0/24)."
  type        = string
  default     = "10.1.1.0/24"
}

variable "storage_bucket_labels" {
  description = "Labels to apply to the storage buckets."
  type        = map(string)
  default     = {}
}

variable "tfstate_bucket_force_destroy" {
  description = "If true, the state bucket will be deleted even if it contains objects."
  type        = bool
  default     = false
}

variable "encrypt_gcs_bucket_tfstate" {
  description = "Whether to encrypt the Terraform state GCS bucket with CMEK using KMS."
  type        = bool
  default     = false
}

variable "kms_prevent_destroy" {
  description = "If set to false, allow deleting KMS keyring and keys when destroying the module."
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Project deletion policy. Use 'DELETE' for sandbox/test environments."
  type        = string
  default     = "PREVENT"
}
