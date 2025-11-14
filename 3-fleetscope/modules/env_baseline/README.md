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
| additional\_project\_role\_identities | (Optional) A list of additional identities to assign roles at the project level for the fleet project. Use the following formats for specific Kubernetes identities:<br><br>- **Specific Service Account:** For all Pods using a specific Kubernetes ServiceAccount:<br>  `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/SERVICEACCOUNT`<br><br>- **Namespace-Wide Access:** For all Pods in a namespace, regardless of the service account or cluster:<br>  `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/namespace/NAMESPACE`<br><br>- **Cluster-Wide Access:** For all Pods in a specific cluster:<br>  `principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/kubernetes.cluster/https://container.googleapis.com/v1/projects/PROJECT_ID/locations/LOCATION/clusters/CLUSTER_NAME`<br><br>Note: Namespace-Wide Access is Granted for all namespace created with `namespace_ids`.<br>More details can be found here:<br>https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#principal-id-examples | `list(string)` | `[]` | no |
| attestation\_evaluation\_mode | How this admission rule will be evaluated. Possible values are: ALWAYS\_ALLOW, REQUIRE\_ATTESTATION, ALWAYS\_DENY | `string` | `"ALWAYS_ALLOW"` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | `null` | no |
| binary\_authz\_admission\_whitelist\_patterns | An image name pattern to whitelist, in the form registry/path/to/image. This supports a trailing * as a wildcard, but this is allowed only in text after the registry/ part. | `list(string)` | `[]` | no |
| cluster\_membership\_ids | The membership IDs in the scope | `list(string)` | n/a | yes |
| cluster\_project\_id | The cluster project ID | `string` | n/a | yes |
| cluster\_service\_accounts | Cluster nodes services accounts. | `list(string)` | n/a | yes |
| config\_sync\_branch | The branch of the repository to sync from. Default: master | `string` | `"master"` | no |
| config\_sync\_policy\_dir | The path within the Git repository that represents the top level of the repo to sync | `string` | `null` | no |
| config\_sync\_repository\_url | The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored. | `string` | `""` | no |
| config\_sync\_secret\_type | The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret | `string` | `"gcpserviceaccount"` | no |
| disable\_istio\_on\_namespaces | List the namespaces where you don't want the service mesh to be enabled (i.e. sidecar proxy injection). Ensure that the namespace names match exactly with those defined in 'var.namespace\_ids'. | `list(string)` | `[]` | no |
| enable\_kueue | Enables Kueue private installation. | `bool` | `false` | no |
| enable\_multicluster\_discovery | Enables Multicluster discovery. | `bool` | `true` | no |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| fleet\_project\_id | The fleet project ID | `string` | n/a | yes |
| namespace\_ids | The fleet namespace IDs with team | `map(string)` | n/a | yes |
| network\_project\_id | The network project ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| attestor\_id | Attestor ID. |
| cluster\_service\_accounts | Cluster Service Accounts |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
