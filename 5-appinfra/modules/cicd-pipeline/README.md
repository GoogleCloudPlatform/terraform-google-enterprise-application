# Cymbal Bank deployment example

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| additional\_substitutions | A map of additional substitution variables for Google Cloud Build Trigger Specification. All keys must start with an underscore (\_). | `map(string)` | `{}` | no |
| app\_build\_trigger\_yaml | Path to the Cloud Build YAML file for the application | `string` | n/a | yes |
| attestation\_kms\_key | The KMS Key ID to be used by attestor in format projects/PROJECT\_ID/locations/KMS\_KEY\_LOCATION/keyRings/KMS\_KEYRING\_NAME/cryptoKeys/KMS\_KEY\_NAME/cryptoKeyVersions/KMS\_KEY\_VERSION. | `string` | `null` | no |
| attestor\_id | The attestor name in format projects/PROJECT\_ID/attestors/ATTESTOR\_NAME. | `string` | n/a | yes |
| binary\_authorization\_image | The Binary Authorization image to be used to create attestation. | `string` | `null` | no |
| binary\_authorization\_repository\_id | The Binary Authorization artifact registry where the image to be used to create attestation is stored with format `projects/{{project}}/locations/{{location}}/repositories/{{repository_id}}`. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| buckets\_force\_destroy | When deleting the bucket for storing CICD artifacts, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| ci\_build\_included\_files | (Optional) includedFiles are file glob matches using https://golang.org/pkg/path/filepath/#Match extended with support for **. If any of the files altered in the commit pass the ignoredFiles filter and includedFiles is empty, then as far as this filter is concerned, we should trigger the build. If any of the files altered in the commit pass the ignoredFiles filter and includedFiles is not empty, then we make sure that at least one of those files matches a includedFiles glob. If not, then we do not trigger a build. | `list(string)` | `[]` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = map(<br>      object({<br>        repository_name = string<br>        repository_url  = string<br>      })<br>    )<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>  })</pre> | n/a | yes |
| cluster\_service\_accounts | Cluster services accounts to be granted the Artifact Registry reader role. | `map(string)` | n/a | yes |
| env\_cluster\_membership\_ids | Env Cluster Membership IDs | <pre>map(object({<br>    cluster_membership_ids = list(string)<br>  }))</pre> | n/a | yes |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| project\_id | CI/CD project ID | `string` | n/a | yes |
| region | CI/CD Region (e.g. us-central1) | `string` | n/a | yes |
| repo\_branch | Branch to sync ACM configs from & trigger CICD if pushed to. | `string` | n/a | yes |
| repo\_name | Short version of repository to sync ACM configs from & use source for CI (e.g. 'bank-of-anthos' for https://www.github.com/GoogleCloudPlatform/bank-of-anthos) | `string` | n/a | yes |
| service\_name | service name (e.g. 'transactionhistory') | `string` | n/a | yes |
| team\_name | Team name (e.g. 'ledger'). This will be the prefix to the service CI Build Trigger Name. | `string` | n/a | yes |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| cloudbuild\_service\_account | Service Account created to run Cloud Build. |
| clouddeploy\_targets\_names | Cloud deploy targets names. |
| service\_repository\_name | The Source Repository name. |
| service\_repository\_project\_id | The Source Repository project id. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

