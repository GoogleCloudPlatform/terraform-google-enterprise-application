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

variable "project_id" {
  type        = string
  description = "Google Cloud project ID in which to deploy all example resources"
}

variable "region" {
  type        = string
  description = "Google Cloud region for deployments"
  default     = "us-central1"
}

variable "teams" {
  type        = map(string)
  description = "A map of string at the format {\"namespace\" = \"groupEmail\"}"
}

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null


  validation {
    condition     = var.service_perimeter_name != ""
    error_message = "service_perimeter_name cannot be empty, only null or a valid value."
  }
}

variable "service_perimeter_mode" {
  description = "(VPC-SC) Service perimeter mode: ENFORCE, DRY_RUN."
  type        = string
  default     = "ENFORCE"

  validation {
    condition     = contains(["ENFORCE", "DRY_RUN"], var.service_perimeter_mode)
    error_message = "The service_perimeter_mode value must be one of: ENFORCE, DRY_RUN."
  }
}

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
  validation {
    condition     = var.access_level_name != ""
    error_message = "access_level_name cannot be empty, only null or a valid value."
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
}

variable "logging_bucket" {
  description = "Bucket to store logging."
  type        = string
  default     = null
  validation {
    condition     = var.logging_bucket != ""
    error_message = "logging_bucket cannot be empty, only null or a valid value."
  }
}

variable "bucket_kms_key" {
  description = "KMS Key id to be used to encrypt bucket."
  type        = string
  default     = null
  validation {
    condition     = var.bucket_kms_key != ""
    error_message = "bucket_kms_key cannot be empty, only null or a valid value."
  }
}

variable "network_id" {
  description = "The network ID where the private worker pool is going to be peered. If not provided, a new network is going to be created."
  type        = string
  default     = null

  validation {
    condition     = var.network_id != ""
    error_message = "network_id cannot be empty, only null or a valid value."
  }
}

variable "create_nat" {
  description = "Enables Cloud NAT creation for Private Worker Pool, disable if your network already has one created."
  type        = bool
  default     = true
}


variable "attestation_kms_key" {
  type        = string
  description = "The KMS Key ID to be used by attestor."
}
variable "cloudbuildv2_repository_config" {
  description = <<-EOT
  Configuration for integrating repositories with Cloud Build v2:
    - repo_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.
    - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:
        - repository_name: The name of the repository.
        - repository_url: The URL of the repository.
    - github_secret_id: (Optional) The personal access token for GitHub authentication.
    - github_app_id_secret_id: (Optional) The application ID for a GitHub App used for authentication.
    - gitlab_read_authorizer_credential_secret_id: (Optional) The read authorizer credential for GitLab access.
    - gitlab_authorizer_credential_secret_id: (Optional) The authorizer credential for GitLab access.
    - gitlab_webhook_secret_id: (Optional) The secret ID for the GitLab WebHook.
    - gitlab_enterprise_host_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.
    - gitlab_enterprise_service_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.
    - gitlab_enterprise_ca_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.
  Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.
  Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.
  Note: If 'cloudbuildv2_repository_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default.
  EOT
  type = object({
    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR
    # repositories to be created
    repositories = map(
      object({
        repository_name = string
        repository_url  = string
      })
    )
    # Credential Config for each repository type
    github_secret_id                            = optional(string)
    github_app_id_secret_id                     = optional(string)
    gitlab_read_authorizer_credential_secret_id = optional(string)
    gitlab_authorizer_credential_secret_id      = optional(string)
    gitlab_webhook_secret_id                    = optional(string)
    gitlab_enterprise_host_uri                  = optional(string)
    gitlab_enterprise_service_directory         = optional(string)
    gitlab_enterprise_ca_certificate            = optional(string)
  })

  validation {
    condition = (
      var.cloudbuildv2_repository_config.repo_type == "GITHUBv2" ? (
        var.cloudbuildv2_repository_config.github_secret_id != null &&
        var.cloudbuildv2_repository_config.github_app_id_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_webhook_secret_id == null
        ) : var.cloudbuildv2_repository_config.repo_type == "GITLABv2" ? (
        var.cloudbuildv2_repository_config.github_secret_id == null &&
        var.cloudbuildv2_repository_config.github_app_id_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_webhook_secret_id != null
      ) : var.cloudbuildv2_repository_config.repo_type == "CSR" ? true : false
    )
    error_message = "You must specify a valid repo_type ('GITHUBv2', 'GITLABv2', or 'CSR'). For 'GITHUBv2', all 'github_' prefixed variables must be defined and no 'gitlab_' prefixed variables should be defined. For 'GITLABv2', all 'gitlab_' prefixed variables must be defined and no 'github_' prefixed variables should be defined."
  }

}
