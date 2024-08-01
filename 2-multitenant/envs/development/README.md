<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| apps | Applications | <pre>map(object({<br>    ip_address_names = optional(list(string))<br>    certificates     = optional(map(list(string)))<br>  }))</pre> | n/a | yes |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| app\_certificates | App Certificates |
| app\_ip\_addresses | App IP Addresses |
| app\_service\_accounts | IP Addresses |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
