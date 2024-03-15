# EAB: Bootstrap phase

The bootstrap phase establishes the 3 initial pipelines of the Enterprise Application blueprint. These pipelines are:
- the Multitenant Infrastructure pipeline
- the Application Factory
- the Fleet-Scope pipeline

Each pipeline has the following associated resources:
- 2 Cloud Build triggers
  - 1 trigger to run Terraform Plan commands upon changes to a non-main git branch
  - 1 trigger to run Terraform Apply commands upon changes to the main git branch
- 3 Cloud Storage buckets
  - Terraform State bucket, to store the current state
  - Build Artifacts bucket, to store any artifacts generated during the build process, such as `.tfplan` files
  - Build Logs bucket, to store the logs from the build process
- 1 service account for executing the Cloud Build build process

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| project\_id | Project ID for initial resources | `string` | n/a | yes |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "non\\-production",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifacts\_bucket | Bucket for storing TF plans |
| logs\_bucket | Bucket for storing TF logs |
| project\_id | Project ID |
| source\_repo\_urls | n/a |
| state\_bucket | Bucket for storing TF state |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
