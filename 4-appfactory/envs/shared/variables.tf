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

variable "common_folder_id" {
  type        = string
  description = "Folder ID in which to create all application admin projects, must be prefixed with 'folders/'"

  validation {
    condition     = can(regex("^folders/", var.common_folder_id))
    error_message = "The folder ID must be prefixed with 'folders/'."
  }
}

variable "org_id" {
  type        = string
  description = "Google Cloud Organization ID."
}

variable "billing_account" {
  type        = string
  description = "Billing Account ID for application admin project resources."
}

variable "envs" {
  description = "Environments"
  type = map(object({
    billing_account    = string
    folder_id          = string
    network_project_id = string
    network_self_link  = string
    org_id             = string
    subnets_self_links = list(string)
  }))
}

variable "bucket_prefix" {
  description = "Name prefix to use for buckets created."
  type        = string
  default     = "bkt"
}

variable "bucket_force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}

variable "location" {
  description = "Location for build buckets."
  type        = string
  default     = "us-central1"
}

variable "trigger_location" {
  description = "Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool."
  type        = string
  default     = "us-central1"
}

variable "tf_apply_branches" {
  description = "List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default."
  type        = list(string)
  default     = ["development", "nonproduction", "production"]
}

variable "remote_state_bucket" {
  description = "Backend bucket to load Terraform Remote State Data from previous steps."
  type        = string
}

# Define Application Services
variable "applications" {
  description = <<-EOF
  A map where the key is the application name, containing the configuration for each microservice under the application. Each microservice has the following properties:
  - **admin_project_id** (Optional): Admin project associated with the microservice. This hosts microservice specific CI/CD pipelines. If set, `create_admin_project` must be `false`.
  - **create_infra_project** (Required): Indicates whether an infrastructure project should be created for the microservice (one infra project will be created per environment defines in var.envs).
  - **create_admin_project** (Required): Indicates whether a Admin project should be created for the microservice.
  EOF
  type = map(map(object({
    admin_project_id     = optional(string, null)
    create_infra_project = bool
    create_admin_project = bool
  })))

  validation {
    condition = alltrue(
      [
        for app_name, microservices in var.applications : alltrue(
          [
            for microservice_name, microservice_obj in microservices :
            (microservice_obj.admin_project_id == null || microservice_obj.create_admin_project == false)
          ]
        )
      ]
    )
    error_message = "If admin_project_id is specified, the corresponding create_admin_project must be set to false."
  }
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
    - secret_project_id: (Optional) The project id where the secret is stored.
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
    secret_project_id                           = optional(string)
  })

  validation {
    condition = (
      var.cloudbuildv2_repository_config.repo_type == "GITHUBv2" ? (
        var.cloudbuildv2_repository_config.github_secret_id != null &&
        var.cloudbuildv2_repository_config.github_app_id_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_webhook_secret_id == null &&
        var.cloudbuildv2_repository_config.secret_project_id != null
        ) : var.cloudbuildv2_repository_config.repo_type == "GITLABv2" ? (
        var.cloudbuildv2_repository_config.github_secret_id == null &&
        var.cloudbuildv2_repository_config.github_app_id_secret_id == null &&
        var.cloudbuildv2_repository_config.gitlab_read_authorizer_credential_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id != null &&
        var.cloudbuildv2_repository_config.gitlab_webhook_secret_id != null &&
        var.cloudbuildv2_repository_config.secret_project_id != null
      ) : var.cloudbuildv2_repository_config.repo_type == "CSR" ? true : false
    )
    error_message = "You must specify a valid repo_type ('GITHUBv2', 'GITLABv2', or 'CSR'). For 'GITHUBv2', all 'github_' prefixed variables must be defined and no 'gitlab_' prefixed variables should be defined. For 'GITLABv2', all 'gitlab_' prefixed variables must be defined and no 'github_' prefixed variables should be defined."
  }

}

variable "kms_project_id" {
  description = "Custom KMS Key project to be granted KMS Admin to the Cloud Build service account."
  type        = string
  default     = null
}

variable "service_perimeter_name" {
  description = "(VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter."
  type        = string
  default     = null
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

variable "infra_project_apis" {
  type        = list(string)
  description = "List of APIs to enable for environment-specific application infra projects"
  default = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
  ]
}
