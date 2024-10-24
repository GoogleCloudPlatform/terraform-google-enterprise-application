# Standalone Single-Project Example
The standalone example deploys the entire enterprise application blueprint into a single project for the purposes of simplified demonstation. Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | n/a | yes |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->