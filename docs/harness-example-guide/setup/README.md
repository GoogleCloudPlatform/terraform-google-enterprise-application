# Harness Setup for Single-Project Examples

This harness setup provisions the required prerequisite resources in Google Cloud to test and deploy the Single-Project Standalone reference examples (`default-example`, `agent`, `llm-model`, `cymbal-bank`, etc.) of the Enterprise Application Blueprint (EAB).

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | The Google Cloud Billing Account ID (e.g., XXXXXX-YYYYYY-ZZZZZZ). | `string` | n/a | yes |
| cloud\_build\_sa | Optional Cloud Build Service Account email to be granted KMS Encrypt/Decrypt and Attestation roles. If empty, the project default Cloud Build service account will be used. | `string` | `""` | no |
| create\_workerpool | Whether to pre-provision a dedicated Cloud Build Private Worker Pool with NAT VM. If false, single-project examples provision their own worker pools via standalone-harness. | `bool` | `false` | no |
| encrypt\_gcs\_bucket\_tfstate | Whether to encrypt the Terraform state GCS bucket with CMEK using KMS. | `bool` | `false` | no |
| folder\_id | The folder ID where the harness seed folder and project will be created. | `string` | n/a | yes |
| kms\_prevent\_destroy | If set to false, allow deleting KMS keyring and keys when destroying the module. | `bool` | `true` | no |
| org\_id | The numeric Google Cloud Organization ID. | `string` | n/a | yes |
| project\_deletion\_policy | Project deletion policy. Use 'DELETE' for sandbox/test environments. | `string` | `"PREVENT"` | no |
| region | The Google Cloud region for KMS, Logging bucket, tfstate bucket, and worker pools. | `string` | `"us-central1"` | no |
| storage\_bucket\_labels | Labels to apply to the storage buckets. | `map(string)` | `{}` | no |
| tfstate\_bucket\_force\_destroy | If true, the state bucket will be deleted even if it contains objects. | `bool` | `false` | no |
| workerpool\_machine\_type | The machine type for the Cloud Build Private Worker Pool. | `string` | `"e2-standard-4"` | no |
| workerpool\_nat\_subnet\_ip | The CIDR block for the worker pool NAT proxy subnet (e.g., 10.1.1.0/24). | `string` | `"10.1.1.0/24"` | no |
| workerpool\_peering\_address | The internal IP address for the Cloud Build Private Worker Pool VPC peering range (e.g., 10.3.3.0). | `string` | `"10.3.3.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| attestation\_kms\_key | The KMS key ID for Binary Authorization asymmetric attestation signing. |
| billing\_account | The billing account ID. |
| bucket\_kms\_key | The KMS key ID for Cloud Storage bucket CMEK encryption. |
| logging\_bucket | The GCS logging bucket name for Cloud Build and deployment logs. |
| network\_id | The network ID/self-link of the pre-provisioned VPC (if create\_workerpool is enabled). |
| org\_id | The organization ID. |
| project\_id | The Google Cloud project ID for deploying single-project examples. |
| project\_number | The Google Cloud project number. |
| region | The Google Cloud region for deployments. |
| seed\_folder\_id | The folder ID created for the seed/harness project. |
| state\_bucket | The Cloud Storage bucket for Terraform remote state backend. |
| state\_kms\_key | The KMS key ID for Terraform state bucket CMEK encryption. |
| workerpool\_id | The ID of the pre-provisioned Cloud Build private worker pool (if create\_workerpool is enabled). |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
