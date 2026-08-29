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

variable "sa_email" {
  description = "The ci service account email created by setup to run the tests."
  type        = map(string)
}

variable "cloud_build_sa" {
  description = "Cloud Build Service Account email to be granted Encrypt/Decrypt role."
  type        = string
}
variable "seed_folder_id" {
  description = "The folder to deploy in"
  type        = string
}

variable "org_id" {
  description = "The numeric organization id"
  type        = string
}

variable "billing_account" {
  description = "The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ"
  type        = string
}

variable "region" {
  description = "Region where KMS and Logging bucket will be deployed."
  type        = string
  default     = "us-central1"
}

variable "harness_project_ids" {
  description = "The project ids to be added as service project."
  type        = list(string)
}

variable "seed_project_number" {
  description = "The seed project number."
  type        = string
}

variable "logging_kms_crypto_id" {
  description = "KMS key id used to encrypt buckets."
  type        = string
}

variable "attestation_kms_crypto_id" {
  description = "KMS key id used for image attestation."
  type        = string
}

variable "logging_bucket_name" {
  description = "The logging bucket name."
  type        = string
}
