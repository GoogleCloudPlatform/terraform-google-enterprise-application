<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| applications | A map where the key is the application name, containing the configuration for each microservice under the application. Each microservice has the following properties:<br>- **admin\_project\_id** (Optional): Admin project associated with the microservice. This hosts microservice specific CI/CD pipelines. If set, `create_admin_project_id` must be `false`.<br>- **create\_infra\_project** (Required): Indicates whether an infrastructure project should be created for the microservice (one infra project will be created per environment defines in var.envs).<br>- **create\_admin\_project** (Required): Indicates whether a Admin project should be created for the microservice. | <pre>map(map(object({<br>    admin_project_id        = optional(string, null)<br>    create_infra_project_id    = bool<br>    create_admin_project_id = bool<br>  })))</pre> | n/a | yes |
| billing\_account | Billing Account ID for application admin project resources. | `string` | n/a | yes |
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| common\_folder\_id | Folder ID in which to create all application admin projects, must be prefixed with 'folders/' | `string` | n/a | yes |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| org\_id | Google Cloud Organization ID. | `string` | n/a | yes |
| remote\_state\_bucket | Backend bucket to load Terraform Remote State Data from previous steps. | `string` | n/a | yes |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "nonproduction",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |

## Outputs

| Name | Description |
|------|-------------|
| app-folders-ids | Pair of app-name and folder\_id |
| app-group | Description on the app-group components |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
