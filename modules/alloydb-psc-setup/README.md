# AlloyDB PSC Setup Module

This module provisions an AlloyDB cluster and instance configured with Private Service Connect (PSC), registers a compute forwarding rule on the consumer VPC network, and grants Workload Identity access to the AlloyDB instance.

This module creates the following resources:
- AlloyDB Cluster and primary instance with PSC enabled
- AlloyDB read-pool instance (optional)
- Compute Forwarding Rule (PSC endpoint forwarding rule) on the consumer VPC
- IAM binding granting the Workload Identity service account the `roles/alloydb.admin` role

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app\_project\_id | App Project ID | `string` | n/a | yes |
| db\_region | Database Region | `string` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| network\_name | The name of the network in which PSC attachment will be provisioned | `string` | n/a | yes |
| network\_project\_id | The ID of the project in which PSC attachment will be provisioned | `string` | n/a | yes |
| psc\_consumer\_fwd\_rule\_ip | Consumer psc endpoint IP address | `string` | n/a | yes |
| workload\_identity\_principal | Workload Identity Principal to assign Cloud AlloyDB Admin (roles/alloydb.admin) role. Format: https://cloud.google.com/billing/docs/reference/rest/v1/Policy#Binding | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
