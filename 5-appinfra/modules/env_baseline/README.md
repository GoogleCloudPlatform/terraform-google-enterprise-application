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
| db\_name | Database name | `string` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
