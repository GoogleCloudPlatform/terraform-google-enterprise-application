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
| network\_project\_id | The ID of the project in which attachment will be provisioned | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| primary\_instance | primary instance created |
| primary\_instance\_id | ID of the primary instance created |
| primary\_psc\_attachment\_link | The private service connect (psc) attachment created for primary instance |
| psc\_consumer\_fwd\_rule\_ip | Consumer psc endpoint created |
| psc\_dns\_name | he DNS name of the instance for PSC connectivity. Name convention: ...alloydb-psc.goog |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
