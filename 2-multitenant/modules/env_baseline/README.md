# Multitenant Infrastructure: environment baseline module

This module defines the per-environment multitenant resources deployed via the multitenant infrastructure pipeline.

The following resources are created:
- GKE cluster(s)
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_subnetworks | The subnetwork self\_links for clusters | `list(string)` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| project\_id | Project ID for cluster memberships | `string` | n/a | yes |
| release\_channel | The release channel for the clusters | `string` | `"REGULAR"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_ids | GKE cluster IDs |
| cluster\_membership\_ids | GKE cluster membership IDs |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
