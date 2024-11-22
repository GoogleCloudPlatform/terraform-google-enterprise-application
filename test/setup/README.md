# Test Setup

The Setup module creates the required prerequisite resources to deploy the blueprint in the test environment. This includes the following resources:
- an initial Google Cloud Project
- a service account to execute the tests, with required IAM roles for creating the blueprint resources
- activates required APIs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| branch\_name | The branch starting the build. | `string` | n/a | yes |
| folder\_id | The folder to deploy in | `string` | n/a | yes |
| org\_id | The numeric organization id | `string` | n/a | yes |
| single\_project | The example which will be tested, if is true, single project infra will be created; if is false multitentant infra will be created | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| billing\_account | n/a |
| common\_folder\_id | n/a |
| envs | n/a |
| org\_id | n/a |
| project\_id | n/a |
| sa\_key | n/a |
| teams | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
