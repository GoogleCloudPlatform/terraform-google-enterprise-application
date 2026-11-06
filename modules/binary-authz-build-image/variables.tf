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

variable "project_id" {
  description = "Project ID for initial resources"
  type        = string
}

variable "attestation_repository_name" {
  description = "The Artifact repository name to store the BinAuthz image."
  type        = string
}

variable "location" {
  description = "Location for artifact registry to store binary authz image."
  type        = string
}

variable "binary_auth_image_version" {
  description = "Binary Authorization image versions tag."
  type        = string
  default     = "v1.0"
}

variable "service_account_id" {
  description = "The service account ID in the format projects/PROJECT_ID/serviceAccounts/EMAIL to run the Cloud Build job. If null, a service account will be created. A supplied account must already have roles/logging.logWriter and access to the build logs bucket."
  type        = string
  default     = null

  validation {
    condition     = var.service_account_id == null || can(regex("^projects/[^/]+/serviceAccounts/[^/]+@[^/]+$", var.service_account_id))
    error_message = "service_account_id must be null or in the format projects/PROJECT_ID/serviceAccounts/EMAIL."
  }
}

variable "service_account_name" {
  description = "The name/ID of the service account to create if service_account_id is not provided (must be 6-30 characters)."
  type        = string
  default     = "sa-binauthz-builder"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{4,28})[a-z0-9]$", var.service_account_name))
    error_message = "service_account_name must be 6-30 characters, start with a lowercase letter, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "bucket_logs_url" {
  description = "Bucket url to store build logs."
  type        = string
  default     = null

  validation {
    condition     = var.bucket_logs_url != ""
    error_message = "bucket_logs_url cannot be empty, only null or a valid value."
  }
}

variable "workerpool_id" {
  description = <<-EOT
    Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.

    The expected format is:
    `projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.

    If you are using worker pools from a different project, ensure that you grant the
    `roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:
    `service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com`
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.workerpool_id != ""
    error_message = "workerpool_id cannot be empty, only null or a valid value."
  }

  validation {
    condition     = var.workerpool_id == null ? true : can(regex("^projects/[a-z0-9-]+/locations/[a-z0-9-]+/workerPools/[a-z0-9-]+$", var.workerpool_id))
    error_message = "The workerpool_id must follow the exact format: 'projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME'."
  }
}

variable "module_dependencies" {
  description = "A list of dependencies to wait for before running the gcloud script"
  type        = list(any)
  default     = []
}
