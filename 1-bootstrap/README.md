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
| project\_id | Project ID for initial resources | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| state\_buckets | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
