<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | Billing Account ID for application admin project resources. | `string` | n/a | yes |
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| common\_folder\_id | Folder ID in which to create all application admin projects | `string` | n/a | yes |
| envs | n/a | `map(any)` | n/a | yes |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| org\_id | Google Cloud Organization ID. | `string` | n/a | yes |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "non\\-production",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |

## Outputs

| Name | Description |
|------|-------------|
| app\_admin\_project\_id | Project ID of the application admin project. |
| app\_cloudbuild\_workspace\_apply\_trigger\_id | ID of the apply cloud build trigger. |
| app\_cloudbuild\_workspace\_artifacts\_bucket\_name | Artifacts bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_logs\_bucket\_name | Logs bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_plan\_trigger\_id | ID of the plan cloud build trigger. |
| app\_cloudbuild\_workspace\_state\_bucket\_name | Terraform state bucket name for the application workspace. |
| app\_env\_project\_ids | Application environment projects IDs. |
| app\_infra\_repository\_name | Name of the application infrastructure repository. |
| app\_infra\_repository\_url | URL of the application infrastructure repository. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
