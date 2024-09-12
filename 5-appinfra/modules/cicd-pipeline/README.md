# Cymbal Bank deployment example

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_substitutions | Parameters to be substituted in the build specification. All keys should begin with an underscore. | `map(string)` | `{}` | no |
| buckets\_force\_destroy | When deleting the bucket for storing CICD artifacts, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| env\_cluster\_membership\_ids | Env Cluster Membership IDs | <pre>map(object({<br>    cluster_membership_ids = list(string)<br>  }))</pre> | n/a | yes |
| project\_id | CI/CD project ID | `string` | n/a | yes |
| region | CI/CD Region (e.g. us-central1) | `string` | n/a | yes |
| repo\_branch | Branch to sync ACM configs from & trigger CICD if pushed to. | `string` | n/a | yes |
| repo\_name | Short version of repository to sync ACM configs from & use source for CI (e.g. 'bank-of-anthos' for https://www.github.com/GoogleCloudPlatform/bank-of-anthos) | `string` | n/a | yes |
| service | service name (e.g. 'frontend') | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

