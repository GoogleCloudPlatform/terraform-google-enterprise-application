# Fleet-Scope Infrastructure: environment baseline module

This module defines the per-environment fleet resources deployed via the fleet-scope infrastructure pipeline.

The following resources are created:
- Fleet scope
- Fleet namespace
- Cloud Source Repo
- Config Management
- Service Mesh
- Multicluster Ingress
- Multicluster Service

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_membership\_ids | The membership IDs in the scope | `list(string)` | n/a | yes |
| cluster\_project\_id | The cluster project ID | `string` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| fleet\_project\_id | The fleet project ID | `string` | n/a | yes |
| namespace\_ids | The fleet namespace IDs with team | `map(string)` | n/a | yes |
| network\_project\_id | The network project ID | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
