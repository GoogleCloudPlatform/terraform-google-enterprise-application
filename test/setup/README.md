# Test Setup

The Setup module creates the required prerequisite resources to deploy the blueprint in the test environment. This includes the following resources:
- an initial Google Cloud Project
- a service account to execute the tests, with required IAM roles for creating the blueprint resources
- activates required APIs
- a Hub VPC network (`vpc-eab-hub`) including main subnets and regional managed proxies
- a Network Connectivity Center (NCC) configured with STAR topology, including custom center and edge groups

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| agent | Agent Example being deployed. | `bool` | n/a | yes |
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cloud\_build\_sa | Cloud Build Service Account email to be granted Encrypt/Decrypt role. | `string` | n/a | yes |
| examples\_tested | List of examples to create projects. | `list(string)` | `[]` | no |
| folder\_id | The folder to deploy in | `string` | n/a | yes |
| hpc | HPC Example being deployed. | `bool` | n/a | yes |
| org\_id | The numeric organization id | `string` | n/a | yes |
| region | Region for hub network. | `string` | `"us-central1"` | no |
| single\_project | Single Project example being deployed. | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| billing\_account | Billing account used to be linked at projects. |
| cloud\_build\_sa | The cloud build service account (when using Cloud build). |
| harness\_project\_ids | A list of the projects ids created including seed. |
| harness\_project\_numbers | A list of the projects numbers created including seed. |
| hpc | If is a HPC example being deployed. |
| ncc\_group | The NCC group name. |
| ncc\_hub\_uri | NCC Hub id. |
| org\_id | Organization ID used to create projects. |
| sa\_email | All service accounts email created for examples, including in seed project. |
| sa\_id | All service accounts id created for examples, including in seed project. |
| sa\_key | The seed private key. |
| seed\_folder\_id | Seed folder id. |
| seed\_project\_id | Seed project id. |
| seed\_project\_number | Seed project number. |
| single\_project | If single project examples are being deployed. |
| teams | Workspace groups id. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
