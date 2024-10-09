<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| acronym | The acronym of the application. | `string` | n/a | yes |
| billing\_account | Billing Account ID for application admin project resources. | `string` | n/a | yes |
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| cicd\_project | The CI/CD project associated with the microservice. If set, `create_admin_project` must be set to `false`. | `string` | n/a | yes |
| cloudbuild\_sa\_roles | Optional to assign to custom CloudBuild SA. Map of project name or any static key to object with list of roles. Keys much match keys from var.envs | <pre>map(object({<br>    roles = list(string)<br>  }))</pre> | `{}` | no |
| create\_cicd\_project | Boolean value that indicates whether a CI/CD project should be created for the microservice. | `bool` | n/a | yes |
| create\_infra\_project | Boolean value that indicates whether an infrastructure project should be created for the microservice. | `bool` | n/a | yes |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| folder\_id | Folder ID of parent folder for application admin resources. If deploying on the enterprise foundation blueprint, this is usually the 'common' folder. | `string` | n/a | yes |
| infra\_project | The infrastructure project associated with the microservice. If set, `create_infra_project` must be set to `false`. | `string` | n/a | yes |
| infra\_project\_apis | List of APIs to enable for environment-specific application infra projects | `list(string)` | <pre>[<br>  "iam.googleapis.com",<br>  "cloudresourcemanager.googleapis.com",<br>  "serviceusage.googleapis.com",<br>  "cloudbilling.googleapis.com"<br>]</pre> | no |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| org\_id | Google Cloud Organization ID. | `string` | n/a | yes |
| service\_name | The name of a single service application. | `string` | `"demo-app"` | no |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "nonproduction",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |

## Outputs

| Name | Description |
|------|-------------|
| app\_cicd\_project | Project ID of the application admin project. |
| app\_cloudbuild\_workspace\_apply\_trigger\_id | ID of the apply cloud build trigger. |
| app\_cloudbuild\_workspace\_artifacts\_bucket\_name | Artifacts bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_logs\_bucket\_name | Logs bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_plan\_trigger\_id | ID of the plan cloud build trigger. |
| app\_cloudbuild\_workspace\_state\_bucket\_name | Terraform state bucket name for the application workspace. |
| app\_infra\_project\_ids | Application environment projects IDs. |
| app\_infra\_repository\_name | Name of the application infrastructure repository. |
| app\_infra\_repository\_url | URL of the application infrastructure repository. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
