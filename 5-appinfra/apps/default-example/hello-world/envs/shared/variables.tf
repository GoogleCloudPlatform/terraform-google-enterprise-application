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

variable "region" {
  description = "CI/CD region"
  type        = string
  default     = "us-central1"
}

variable "buckets_force_destroy" {
  description = "When deleting the bucket for storing CICD artifacts, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}

variable "bucket_prefix" {
  description = "Name prefix to use for buckets created."
  type        = string
  default     = "bkt"
}

variable "remote_state_bucket" {
  description = "Backend bucket to load Terraform Remote State Data from previous steps."
  type        = string
}

variable "environment_names" {
  description = "A list of environment names."
  type        = list(string)
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

variable "access_level_name" {
  description = "(VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter."
  type        = string
  default     = null
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

variable "attestation_kms_key" {
  type        = string
  description = "The KMS Key ID to be used by attestor."
  default     = null
}
