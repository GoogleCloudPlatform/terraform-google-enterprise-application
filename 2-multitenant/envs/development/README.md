<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cloudsql\_self\_links | Cloud SQL Self Links |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| clusters\_ids | GKE cluster IDs |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| ip\_address\_self\_links | IP Address Self Links |
| network\_project\_id | Network Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
