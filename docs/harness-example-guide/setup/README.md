# Harness Setup

This harness setup creates the required prerequisite resources to deploy the harness for the EAB deployment.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| <a name="input_cloud_build_sa"></a> [cloud\_build\_sa](#input\_cloud\_build\_sa) | Cloud Build Service Account email to be granted Encrypt/Decrypt role. | `string` | n/a | yes |
| <a name="input_enabled_environments"></a> [enabled\_environments](#input\_enabled\_environments) | A map of environments to deploy. Set the value to 'true' for each environment you want to create. | `map(bool)` | n/a | yes |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The folder to deploy in | `string` | n/a | yes |
| <a name="input_network_regions_to_deploy"></a> [network\_regions\_to\_deploy](#input\_network\_regions\_to\_deploy) | A list of GCP regions where VPC subnets should be created. Valid options are 'us-central1' and 'us-east4'. | `list(string)` | n/a | yes |
| <a name="input_org_id"></a> [org\_id](#input\_org\_id) | The numeric organization id | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region where KMS and Logging bucket will be deployed. | `string` | n/a | yes |
| <a name="input_workerpool_machine_type"></a> [workerpool\_machine\_type](#input\_workerpool\_machine\_type) | The project to deploy in | `string` | n/a | yes |
| <a name="input_workpool_region"></a> [workpool\_region](#input\_workpool\_region) | The region to deploy in | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_attestation_evaluation_mode"></a> [attestation\_evaluation\_mode](#output\_attestation\_evaluation\_mode) | n/a |
| <a name="output_attestation_kms_key"></a> [attestation\_kms\_key](#output\_attestation\_kms\_key) | n/a |
| <a name="output_billing_account"></a> [billing\_account](#output\_billing\_account) | n/a |
| <a name="output_bucket_kms_key"></a> [bucket\_kms\_key](#output\_bucket\_kms\_key) | n/a |
| <a name="output_cloud_build_sa"></a> [cloud\_build\_sa](#output\_cloud\_build\_sa) | n/a |
| <a name="output_common_folder_id"></a> [common\_folder\_id](#output\_common\_folder\_id) | n/a |
| <a name="output_envs"></a> [envs](#output\_envs) | n/a |
| <a name="output_logging_bucket"></a> [logging\_bucket](#output\_logging\_bucket) | n/a |
| <a name="output_org_id"></a> [org\_id](#output\_org\_id) | n/a |
| <a name="output_seed_project_id"></a> [seed\_project\_id](#output\_seed\_project\_id) | n/a |
| <a name="output_workerpool_id"></a> [workerpool\_id](#output\_workerpool\_id) | n/a |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
