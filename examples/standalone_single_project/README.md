# Standalone Single-Project Example
The standalone example deploys the entire enterprise application blueprint into a single project for the purposes of simplified demonstation. Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| network\_id | Network id | `string` | n/a | yes |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| service\_perimeter\_mode | Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | Service perimeter full name. | `string` | `null` | no |
| subnetwork\_self\_link | Sub-Network self-link | `string` | n/a | yes |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| acronyms | App Acronyms |
| app\_certificates | App Certificates |
| app\_infos | App infos (name, services, team). |
| app\_ip\_addresses | App IP Addresses |
| clouddeploy\_targets\_names | Cloud deploy targets names. |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_project\_number | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
