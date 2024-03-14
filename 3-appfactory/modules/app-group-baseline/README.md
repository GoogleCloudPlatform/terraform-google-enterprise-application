<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application\_name | The name of a single application. | `string` | `"demo-app"` | no |
| billing\_account | Billing Account ID for application admin project resources. | `string` | n/a | yes |
| cloudbuild\_sa\_roles | Optional to assign to custom CloudBuild SA. Map of project name or any static key to object with list of roles. Keys much match keys from var.envs | <pre>map(object({<br>    roles = list(string)<br>  }))</pre> | `{}` | no |
| create\_env\_projects | n/a | `bool` | `true` | no |
| env\_project\_apis | List of APIs to enable for environment-specific application infra projects | `list(string)` | <pre>[<br>  "iam.googleapis.com",<br>  "cloudresourcemanager.googleapis.com",<br>  "serviceusage.googleapis.com",<br>  "cloudbilling.googleapis.com"<br>]</pre> | no |
| envs | n/a | `map(any)` | n/a | yes |
| folder\_id | Folder ID of parent folder for application admin resources. If deploying on the enterprise foundation blueprint, this is usually the 'common' folder. | `string` | n/a | yes |
| org\_id | Google Cloud Organization ID. | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
