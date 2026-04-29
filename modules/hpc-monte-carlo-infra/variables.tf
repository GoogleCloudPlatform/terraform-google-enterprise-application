
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

variable "infra_project" {
  description = "The infrastructure project where resources will be managed."
  type        = string
}

variable "cluster_project" {
  description = "The project that hosts the Kubernetes cluster."
  type        = string
}

variable "region" {
  description = "The region where the cloud resources will be deployed."
  type        = string
}

variable "bucket_force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}

variable "cluster_project_number" {
  description = "The numerical identifier for the cluster project."
  type        = string
}

variable "env" {
  description = "The environment in which resources are deployed (e.g., development, nonproduction, production)."
  type        = string
}

variable "cluster_service_accounts" {
  description = "A map of service accounts emails associated with the Kubernetes cluster, these will be granted access to created Docker images."
  type        = map(any)
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
}

variable "team" {
  description = "Environment Team, must be the same as the fleet scope team"
  type        = string
}

variable "logging_bucket" {
  description = "Bucket to store logging."
  type        = string
  default     = null
}

variable "bucket_kms_key" {
  description = "KMS Key id to be used to encrypt bucket."
  type        = string
  default     = null
}

variable "bucket_prefix" {
  description = "Name prefix to use for buckets created."
  type        = string
  default     = "bkt"
}
