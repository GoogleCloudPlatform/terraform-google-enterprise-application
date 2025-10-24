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

variable "env" {
  description = "The environment to prepare (ex. development)"
  type        = string
}

variable "cluster_project_id" {
  description = "The cluster project ID"
  type        = string
}

variable "fleet_project_id" {
  description = "The fleet project ID"
  type        = string
}

variable "network_project_id" {
  description = "The network project ID"
  type        = string
}

variable "namespace_ids" {
  description = "The fleet namespace IDs with team"
  type        = map(string)
}

variable "cluster_membership_ids" {
  description = "The membership IDs in the scope"
  type        = list(string)
}

variable "cluster_service_accounts" {
  description = "Cluster nodes services accounts."
  type        = list(string)
}

variable "additional_project_role_identities" {
  description = <<-EOF
  (Optional) A list of additional identities to assign roles at the project level for the fleet project. Use the following formats for specific Kubernetes identities:

  - **Specific Service Account:** For all Pods using a specific Kubernetes ServiceAccount:
    `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/SERVICEACCOUNT`

  - **Namespace-Wide Access:** For all Pods in a namespace, regardless of the service account or cluster:
    `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/namespace/NAMESPACE`

  - **Cluster-Wide Access:** For all Pods in a specific cluster:
    `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/PROJECT_ID/locations/LOCATION/clusters/CLUSTER_NAME`

  Note: Namespace-Wide Access is Granted for all namespace created with `namespace_ids`.
  More details can be found here:
  https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#principal-id-examples
  EOF
  type        = list(string)
  default     = []
}

variable "config_sync_secret_type" {
  description = "The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret"
  type        = string
  default     = "gcpserviceaccount"
}

variable "config_sync_repository_url" {
  description = "The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored."
  type        = string
  default     = ""
}

variable "disable_istio_on_namespaces" {
  type        = list(string)
  description = "List the namespaces where you don't want the service mesh to be enabled (i.e. sidecar proxy injection). Ensure that the namespace names match exactly with those defined in 'var.namespace_ids'."
  default     = []
}

variable "config_sync_policy_dir" {
  type        = string
  description = "The path within the Git repository that represents the top level of the repo to sync"
  default     = null
}

variable "config_sync_branch" {
  type        = string
  description = "The branch of the repository to sync from. Default: master"
  default     = "master"
}

variable "attestation_kms_key" {
  type        = string
  description = "The KMS Key ID to be used by attestor."
  default     = null
}

variable "attestation_evaluation_mode" {
  type        = string
  description = "How this admission rule will be evaluated. Possible values are: ALWAYS_ALLOW, REQUIRE_ATTESTATION, ALWAYS_DENY"
  default     = "ALWAYS_ALLOW"
}

variable "binary_authz_admission_whitelist_patterns" {
  type        = list(string)
  description = "An image name pattern to whitelist, in the form registry/path/to/image. This supports a trailing * as a wildcard, but this is allowed only in text after the registry/ part."
  default     = []
}

variable "enable_kueue" {
  type        = bool
  description = "Enables Kueue private installation."
  default     = false
}

variable "enable_multicluster_discovery" {
  type        = bool
  description = "Enables Multicluster discovery."
  default     = true
}
