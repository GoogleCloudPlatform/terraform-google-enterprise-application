# Cymbal Bank deployment example

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_membership\_id | Fleet membership ID for the cluster | `string` | n/a | yes |
| fleet\_project\_id | Project ID where the resources will be deployed | `string` | n/a | yes |
| project\_id | Project ID where the resources will be deployed | `string` | n/a | yes |
| region | Region where regional resources will be deployed (e.g. us-east1) | `string` | n/a | yes |
| sync\_branch | Branch to sync ACM configs from & trigger CICD if pushed to. | `string` | n/a | yes |
| sync\_repo | Short version of repository to sync ACM configs from & use source for CI (e.g. 'bank-of-anthos' for https://www.github.com/GoogleCloudPlatform/bank-of-anthos) | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

