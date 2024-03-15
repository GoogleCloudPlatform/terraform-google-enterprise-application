# Multitenant Infrastructure: environment baseline module

This module defines the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

The following resources are created:
- GKE cluster(s)
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account | The billing account id associated with the project, e.g. XXXXXX-YYYYYY-ZZZZZZ | `string` | n/a | yes |
| cluster\_subnetworks | The subnetwork self\_links for clusters | `list(string)` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| folder\_id | Folder ID | `string` | n/a | yes |
| network\_project\_id | Network Project ID | `string` | n/a | yes |
| org\_id | Organization ID | `string` | n/a | yes |
| release\_channel | The release channel for the clusters | `string` | `"REGULAR"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_ids | GKE cluster IDs |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| fleet\_project\_id | Fleet Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
