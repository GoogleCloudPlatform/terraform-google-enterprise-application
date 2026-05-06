# Harness Setup

This harness setup creates the required prerequisite resources to deploy the harness for the EAB deployment.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cloud\_build\_sa | Cloud Build Service Account email to be granted Encrypt/Decrypt role. | `string` | n/a | yes |
| enabled\_environments | A map of environments to deploy. Set the value to 'true' for each environment you want to create. | `map(bool)` | n/a | yes |
| folder\_id | The folder to deploy in | `string` | n/a | yes |
| network\_regions\_to\_deploy | List of regions where the network resources should be deployed. | `list(string)` | n/a | yes |
| org\_id | The numeric organization id | `string` | n/a | yes |
| proxy\_source\_ranges | A list of IP CIDR ranges for proxies that need access to the VPCs. Change this to match your corporate proxy network. | `list(string)` | n/a | yes |
| region | Region where KMS and Logging bucket will be deployed. | `string` | n/a | yes |
| workerpool\_machine\_type | The workerpool machine type. | `string` | n/a | yes |
| workerpool\_nat\_subnet\_ip | The IP CIDR range for the worker pool NAT proxy subnet (e.g., 10.1.1.0/24). Change this if it conflicts with your corporate network. | `string` | n/a | yes |
| workerpool\_peering\_address | The IP address for the Cloud Build private worker pool peering range (e.g., 10.3.3.0). Change this if it conflicts with your corporate network. | `string` | n/a | yes |
| workpool\_region | The region to deploy in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| attestation\_evaluation\_mode | The attestation evaluation mode, which is set to 'REQUIRE\_ATTESTATION' if there is only one environment, and 'ALWAYS\_ALLOW' otherwise. |
| attestation\_kms\_key | The KMS key for attestation. |
| billing\_account | The billing account ID. |
| bucket\_kms\_key | The KMS key for the bucket. |
| common\_folder\_id | The ID of the common folder. |
| envs | A map of environments to their respective VPC information. |
| logging\_bucket | The name of the logging bucket. |
| org\_id | The organization ID. |
| project\_id | The ID of the seed project. |
| workerpool\_id | The ID of the private worker pool. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
