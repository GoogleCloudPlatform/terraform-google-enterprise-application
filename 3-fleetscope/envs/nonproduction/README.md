<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_namespace\_identities | A map where the key is the namespace name, defining the list of user identities that should be assigned admin permissions within that namespace. The format includes the following properties:<br>- **namespace\_name** (Required): The name of the Kubernetes namespace where the users will be granted permissions.<br>- **user\_identities** (Required): A list of email addresses corresponding to the user identities that will be assigned admin permissions in the specified namespace.<br><br>Example:<br>{<br>  "namespace1" = ["user1@domain.com", "user2@domain.com"],<br>  "namespace2" = ["user3@domain.com"]<br>} | `map(list(string))` | `null` | no |
| config\_sync\_repository\_url | The Git repository url for Config Sync. If `config_sync_secret_type` value is `gcpserviceaccount`, a Cloud Source Repository will automatically be created and this variable will be ignored. | `string` | `""` | no |
| config\_sync\_secret\_type | The type of `Secret` configured for access to the Config Sync Git repo. Must be `ssh`, `cookiefile`, `gcenode`, `gcpserviceaccount`, `githubapp`, `token`, or `none`. Depending on the credential type, additional steps must be executed prior to this step. Refer to the following documentation for guidance: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#git-creds-secret | `string` | `"gcpserviceaccount"` | no |
| namespace\_ids | The fleet namespace IDs with team | `map(string)` | n/a | yes |
| remote\_state\_bucket | Backend bucket to load Terraform Remote State Data from previous steps. | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
