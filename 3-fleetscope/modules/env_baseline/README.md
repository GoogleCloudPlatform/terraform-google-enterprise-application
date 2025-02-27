# Fleet-Scope Infrastructure: environment baseline module

This module defines the per-environment fleet resources deployed via the fleet-scope infrastructure pipeline.

The following resources are created:
- Fleet scope
- Fleet namespace
- Cloud Source Repo
- Config Management
- Service Mesh
- Multicluster Ingress
- Multicluster Service

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_namespace\_identities | A map where the key is the namespace name, defining the list of user identities that should be assigned admin permissions within that namespace. The format includes the following properties:<br>- **namespace\_name** (Required): The name of the Kubernetes namespace where the users will be granted permissions.<br>- **user\_identities** (Required): A list of email addresses corresponding to the user identities that will be assigned admin permissions in the specified namespace.<br><br>Example:<br>{<br>  "namespace1" = ["user1@domain.com", "user2@domain.com"],<br>  "namespace2" = ["user3@domain.com"]<br>} | `map(list(string))` | `null` | no |
| additional\_project\_role\_identities | (Optional) A list of additional identities to assign roles at the project level for the fleet project. Use the following formats for specific Kubernetes identities:<br><br>- **Specific Service Account:** For all Pods using a specific Kubernetes ServiceAccount:<br>  `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/SERVICEACCOUNT`<br><br>- **Namespace-Wide Access:** For all Pods in a namespace, regardless of the service account or cluster:<br>  `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/namespace/NAMESPACE`<br><br>- **Cluster-Wide Access:** For all Pods in a specific cluster:<br>  `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/PROJECT_ID/locations/LOCATION/clusters/CLUSTER_NAME`<br><br>Note: Namespace-Wide Access is Granted for all namespace created with `namespace_ids`.<br>More details can be found here:<br>https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#principal-id-examples | `list(string)` | `[]` | no |
| cluster\_membership\_ids | The membership IDs in the scope | `list(string)` | n/a | yes |
| cluster\_project\_id | The cluster project ID | `string` | n/a | yes |
| cluster\_service\_accounts | Cluster nodes services accounts. | `list(string)` | n/a | yes |
| config\_sync\_repository\_url | The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored. | `string` | `""` | no |
| config\_sync\_secret\_type | The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret | `string` | `"gcpserviceaccount"` | no |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| fleet\_project\_id | The fleet project ID | `string` | n/a | yes |
| namespace\_ids | The fleet namespace IDs with team | `map(string)` | n/a | yes |
| network\_project\_id | The network project ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_service\_accounts | Cluster Service Accounts |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
