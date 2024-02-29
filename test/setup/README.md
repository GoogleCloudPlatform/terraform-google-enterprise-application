# Test Setup

The Setup module creates the required prerequisite resources to deploy the blueprint in the test environment. This includes the following resources:
- an initial Google Cloud Project
- a service account to execute the tests, with required IAM roles for creating the blueprint resources
- activates required APIs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `any` | n/a | yes |
| folder\_id | The folder to deploy in | `any` | n/a | yes |
| org\_id | The numeric organization id | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| envs | n/a |
| project\_id | n/a |
| sa\_key | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
