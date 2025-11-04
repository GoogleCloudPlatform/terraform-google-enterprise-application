# Test Setup

The Setup module creates the required prerequisite resources to deploy the blueprint in the test environment. This includes the following resources:
- an initial Google Cloud Project
- a service account to execute the tests, with required IAM roles for creating the blueprint resources
- activates required APIs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| agent | Agent Example being deployed. | `bool` | n/a | yes |
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cloud\_build\_sa | Cloud Build Service Account email to be granted Encrypt/Decrypt role. | `string` | n/a | yes |
| folder\_id | The folder to deploy in | `string` | n/a | yes |
| hpc | HPC Example being deployed. | `bool` | n/a | yes |
| org\_id | The numeric organization id | `string` | n/a | yes |
| single\_project | Single Project example being deployed. | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| billing\_account | n/a |
| cloud\_build\_sa | n/a |
| hpc | n/a |
| org\_id | n/a |
| sa\_email | n/a |
| sa\_id | n/a |
| sa\_key | n/a |
| seed\_folder\_id | n/a |
| seed\_project\_id | n/a |
| seed\_project\_number | n/a |
| single\_project | n/a |
| teams | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
