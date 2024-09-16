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
