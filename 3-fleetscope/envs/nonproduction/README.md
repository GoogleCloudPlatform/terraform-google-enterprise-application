<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| attestation\_evaluation\_mode | How this admission rule will be evaluated. Possible values are: ALWAYS\_ALLOW, REQUIRE\_ATTESTATION, ALWAYS\_DENY | `string` | `"ALWAYS_ALLOW"` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | `null` | no |
| config\_sync\_branch | The branch of the repository to sync from. Default: master | `string` | `"master"` | no |
| config\_sync\_policy\_dir | The path within the Git repository that represents the top level of the repo to sync | `string` | `null` | no |
| config\_sync\_repository\_url | The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored. | `string` | `""` | no |
| config\_sync\_secret\_type | The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret | `string` | `"gcpserviceaccount"` | no |
| disable\_istio\_on\_namespaces | List the namespaces where you don't want the service mesh to be enabled (i.e. sidecar proxy injection). Ensure that the namespace names match exactly with those defined in 'var.namespace\_ids'. | `list(string)` | `[]` | no |
| enable\_kueue | Enables Kueue private installation. | `bool` | `false` | no |
| namespace\_ids | The fleet namespace IDs with team | `map(string)` | n/a | yes |
| remote\_state\_bucket | Backend bucket to load Terraform Remote State Data from previous steps. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| attestor\_id | Attestor ID. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
