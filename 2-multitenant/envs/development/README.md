<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| apps | A map, where the key is the application name, defining the application configurations with the following properties:<br>- **acronym** (Required): A short identifier for the application with a maximum of 3 characters in length.<br>- **ip\_address\_names** (Optional): A list of IP address names associated with the application.<br>- **certificates** (Optional): A map of certificate names to a list of certificate values required by the application. | <pre>map(object({<br>    acronym          = string<br>    ip_address_names = optional(list(string), [])<br>    certificates     = optional(map(list(string)), {})<br>  }))</pre> | n/a | yes |
| cb\_private\_workerpool\_project\_id | Private Worker Pool Project ID used for Cloud Build Triggers. | `string` | `""` | no |
| cluster\_release\_channel | The release channel for the clusters | `string` | `"REGULAR"` | no |
| deletion\_protection | Whether or not to allow Terraform to destroy the cluster. | `bool` | `true` | no |
| enable\_csi\_gcs\_fuse | Enable the GCS Fuse CSI Driver for HTC example | `bool` | `false` | no |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| acronyms | App Acronyms. |
| app\_certificates | App Certificates. |
| app\_ip\_addresses | App IP Addresses. |
| cluster\_membership\_ids | GKE cluster membership IDs. |
| cluster\_names | GKE cluster names. |
| cluster\_project\_id | Cluster Project ID. |
| cluster\_project\_number | Cluster Project number. |
| cluster\_regions | Regions with clusters. |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type. |
| cluster\_zones | Cluster zones. |
| env | Environments. |
| fleet\_project\_id | Fleet Project ID. |
| network\_names | Network Names. |
| network\_project\_id | Network Project ID. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
