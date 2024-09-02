# App Infrastructure: environment baseline module

This module defines the per-environment app resources deployed via the app infrastructure pipeline.

The following resources are created:
- Cloud SQL PostgreSQL (accounts-db, ledger-db)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app\_project\_id | App Project ID | `string` | n/a | yes |
| cluster\_project\_id | Cluster Project ID | `string` | n/a | yes |
| cluster\_regions | Cluster regions | `list(string)` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| network\_name | The name of the network in which PSC attachment will be provisioned | `string` | n/a | yes |
| network\_project\_id | The ID of the project in which PSC attachment will be provisioned | `string` | n/a | yes |
| psc\_consumer\_fwd\_rule\_ip | Consumer psc endpoint IP address | `string` | n/a | yes |
| workload\_identity\_principal | Workload Identity Principal to assign Cloud AlloyDB Admin (roles/alloydb.admin) role. Format: https://cloud.google.com/billing/docs/reference/rest/v1/Policy#Binding | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
