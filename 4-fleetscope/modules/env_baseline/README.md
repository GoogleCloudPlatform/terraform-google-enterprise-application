# Fleet-Scope Infrastructure: environment baseline module

This module defines the per-environment multitenant resources deployed via the fleet-scope infrastructure pipeline.

The following resources are created:
- GKE fleet and features
- ASM
- ACM
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster\_membership\_ids | The membership IDs in the scope | `list(string)` | n/a | yes |
| env | The environment to prepare (ex. development) | `string` | n/a | yes |
| namespace\_id | The fleet namespace ID | `string` | n/a | yes |
| project\_id | The fleet project ID | `string` | n/a | yes |
| scope\_id | The fleet scope ID | `string` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
