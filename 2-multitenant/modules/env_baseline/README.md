# Multitenant Infrastructure: environment baseline module

This module defines the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

The following resources are created:
- GCP Project (cluster project)
- GKE cluster(s)
- Cloud SQL PostgreSQL (accounts-db, ledger-db)
- Cloud Endpoint
- Cloud Armor
- IP addresses (frontend-ip)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| apps | Applications | <pre>map(object({<br>    ip_address_names = optional(list(string))<br>    certificates     = optional(map(list(string)))<br>  }))</pre> | n/a | yes |
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cluster\_release\_channel | The release channel for the clusters | `string` | `"REGULAR"` | no |
| cluster\_subnetworks | The subnetwork self\_links for clusters | `list(string)` | n/a | yes |
| cluster\_type | GKE multi-tenant cluster types: STANDARD, STANDARD-NAP (Standard with node auto-provisioning), AUTOPILOT | `string` | `"STANDARD-NAP"` | no |
| create\_cluster\_project | Create Cluster Project ID, otherwise the Network Project ID is used | `bool` | `true` | no |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| folder\_id | Folder ID | `string` | n/a | yes |
| network\_project\_id | Network Project ID | `string` | n/a | yes |
| org\_id | Organization ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| app\_certificates | App Certificates |
| app\_ip\_addresses | App IP Addresses |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| cluster\_type | Cluster type |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
