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

variable "additional_namespace_identities" {
  description = <<-EOF
  A map where the key is the namespace name, defining the list of user identities that should be assigned admin permissions within that namespace. The format includes the following properties:
  - **namespace_name** (Required): The name of the Kubernetes namespace where the users will be granted permissions.
  - **user_identities** (Required): A list of email addresses corresponding to the user identities that will be assigned admin permissions in the specified namespace.
  
  Example:
  {
    "namespace1" = ["user1@domain.com", "user2@domain.com"],
    "namespace2" = ["user3@domain.com"]
  }
  EOF
  type        = map(list(string))
  default     = null
}
