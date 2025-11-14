<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| acronym | The acronym of the application. | `string` | n/a | yes |
| admin\_project\_id | The admin project id associated with the microservice. This project will host resources like microservice CI/CD pipelines. If set, `create_admin_project` must be set to `false`. | `string` | n/a | yes |
| billing\_account | Billing Account ID for application admin project resources. | `string` | n/a | yes |
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| cloudbuild\_sa\_roles | Optional to assign to custom CloudBuild SA. Map of project name or any static key to object with list of roles. Keys much match keys from var.envs | <pre>map(object({<br>    roles = list(string)<br>  }))</pre> | `{}` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>  - secret\_project\_id: (Optional) The project id where the secret is stored.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = map(<br>      object({<br>        repository_name = string<br>        repository_url  = string<br>      })<br>    )<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>    secret_project_id                           = optional(string)<br>  })</pre> | n/a | yes |
| cluster\_projects\_ids | Cluster projects ids. | `list(string)` | n/a | yes |
| create\_admin\_project | Boolean value that indicates whether a admin project should be created for the microservice. | `bool` | n/a | yes |
| create\_infra\_project | Boolean value that indicates whether an infrastructure project should be created for the microservice. | `bool` | n/a | yes |
| docker\_tag\_version\_terraform | Docker tag version of image. | `string` | `"latest"` | no |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| folder\_id | Folder ID of parent folder for application admin resources. If deploying on the enterprise foundation blueprint, this is usually the 'common' folder. | `string` | n/a | yes |
| gar\_project\_id | Project ID where the Artifact Registry Repository that Hosts the infrastructure pipeline docker image is located. | `string` | n/a | yes |
| gar\_repository\_name | Artifact Registry repository name where the Docker image for the infrastructure pipeline is stored. | `string` | n/a | yes |
| infra\_project\_apis | List of APIs to enable for environment-specific application infra projects | `list(string)` | <pre>[<br>  "iam.googleapis.com",<br>  "cloudresourcemanager.googleapis.com",<br>  "serviceusage.googleapis.com",<br>  "cloudbilling.googleapis.com"<br>]</pre> | no |
| kms\_project\_id | Custom KMS Key project to be granted KMS Admin and KMS Signer Verifier to the Cloud Build service account. | `string` | `null` | no |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| org\_id | Google Cloud Organization ID. | `string` | n/a | yes |
| remote\_state\_project\_id | The project id where remote state are stored. It will be used to allow egress from VPC-SC if is being used. | `string` | n/a | yes |
| service\_name | The name of a single service application. | `string` | `"demo-app"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | n/a | yes |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "nonproduction",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| app\_admin\_project\_id | Project ID of the application admin project. |
| app\_cloudbuild\_workspace\_apply\_trigger\_id | ID of the apply cloud build trigger. |
| app\_cloudbuild\_workspace\_artifacts\_bucket\_name | Artifacts bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_cloudbuild\_sa\_email | Terraform CloudBuild SA email for the application workspace. |
| app\_cloudbuild\_workspace\_logs\_bucket\_name | Logs bucket name for the application workspace. |
| app\_cloudbuild\_workspace\_plan\_trigger\_id | ID of the plan cloud build trigger. |
| app\_cloudbuild\_workspace\_state\_bucket\_name | Terraform state bucket name for the application workspace. |
| app\_infra\_project\_ids | Application environment projects IDs. |
| app\_infra\_repository\_name | Name of the application infrastructure repository. |
| app\_infra\_repository\_url | URL of the application infrastructure repository. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
