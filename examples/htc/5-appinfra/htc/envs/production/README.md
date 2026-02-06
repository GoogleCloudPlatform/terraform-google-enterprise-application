# Load Test for HTC

## Overview

This is a general purpose gRPC load test.

See the details of running the program in its [src/README.md](src/README.md). See below for
deployment on Google Cloud.

## Deployment with Cloud Shell

The following link will walk you through a quick start in Cloud Shell:

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Fgooglecloudplatform%2Frisk-and-research-blueprints&cloudshell_git_branch=main&cloudshell_workspace=examples%2Frisk%2Floadtest&cloudshell_tutorial=QUICKSTART.md&show=terminal)

## Deploy with Terraform

### Requirements

You must have have the following installed:
* `gcloud` installed (see [installation](https://cloud.google.com/sdk/docs/install))
* `kubectl` installed (see [install tools](https://kubernetes.io/docs/tasks/tools/))
* A bash-based shell (Linux or Mac OS/X)

Note that Cloud Shell meets the requirements.

### Configuration

Create `terraform.tfvars` with the following content:
```
project_id="<project id>"
region="<region>"
zones=["<letter zone1>", "<letter zone2>", "<letter zone3>"]
```

For example in us-central1:
```
project_id="<project id>"
region="us-central1"
zones=["a", "b", "c", "f"]
```

For example in europe-west1:
```
project_id="<project id>"
region="europe-west1"
zones=["b", "c", "d"]
```

### Create infrastructure

Authorize `gcloud` if needed:
```sh
gcloud auth login  --quiet --update-adc
```

Update the `gcloud` project:

```bash
gcloud config set project YOUR_PROJECT_ID
```

You may need to enable some basic APIs for Terraform to work:
```sh
gcloud services enable iam.googleapis.com cloudresourcemanager.googleapis.com
```

Initialize and run terraform:
```sh
terraform init
terraform apply
```

NOTE: While running the terraform if the APIs are newly enabled, there may be
timing errors and terraform apply will need to be re-run.

## Seeing infrastructure & Running Test Workloads

### See what's from terraform

Inspect the possible run scripts:
```sh
terraform output
```

Key variable outputs:
 * local_test_scripts contain a list of shell scripts which you can run for different loadtests.
 * get_credentials is the command line to fetch the credentials for kubectl.
 * lookerstudio_create_dashboard_url is a link to create a new Lookerstudio Dashboard from a template.
 * monitoring_dashboard_url is a custom made monitoring dashboard for loadtest.

### Running the GUI

Create a virtual environment:
```sh
python3 -m venv ui/.venv
ui/.venv/bin/python3 -m pip install -r ui/requirements.txt
```

Run the Gradio dashboard:
```sh
ui/.venv/bin/python3 ui/main.py generated/config.yaml
```

Use port 8080 or preview 8080 in the Cloud Shell (Webpreview). This allows you to load
tests, inspect the jobs from BigQuery (similar to the dashboard), and has some deep
links into the Console.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| buckets\_force\_destroy | When deleting the bucket for storing CICD artifacts, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| cloudbuildv2\_repository\_config | Configuration for integrating repositories with Cloud Build v2:<br>  - repo\_type: Specifies the type of repository. Supported types are 'GITHUBv2', 'GITLABv2', and 'CSR'.<br>  - repositories: A map of repositories to be created. The key must match the exact name of the repository. Each repository is defined by:<br>      - repository\_name: The name of the repository.<br>      - repository\_url: The URL of the repository.<br>  - github\_secret\_id: (Optional) The personal access token for GitHub authentication.<br>  - github\_app\_id\_secret\_id: (Optional) The application ID for a GitHub App used for authentication.<br>  - gitlab\_read\_authorizer\_credential\_secret\_id: (Optional) The read authorizer credential for GitLab access.<br>  - gitlab\_authorizer\_credential\_secret\_id: (Optional) The authorizer credential for GitLab access.<br>  - gitlab\_webhook\_secret\_id: (Optional) The secret ID for the GitLab WebHook.<br>  - gitlab\_enterprise\_host\_uri: (Optional) The URI of the GitLab Enterprise host this connection is for. If not specified, the default value is https://gitlab.com.<br>  - gitlab\_enterprise\_service\_directory: (Optional) Configuration for using Service Directory to privately connect to a GitLab Enterprise server. This should only be set if the GitLab Enterprise server is hosted on-premises and not reachable by public internet. If this field is left empty, calls to the GitLab Enterprise server will be made over the public internet. Format: projects/{project}/locations/{location}/namespaces/{namespace}/services/{service}.<br>  - gitlab\_enterprise\_ca\_certificate: (Optional) SSL certificate to use for requests to GitLab Enterprise.<br>Note: When using GITLABv2, specify `gitlab_read_authorizer_credential` and `gitlab_authorizer_credential` and `gitlab_webhook_secret_id`.<br>Note: When using GITHUBv2, specify `github_pat` and `github_app_id`.<br>Note: If 'cloudbuildv2\_repository\_config' variable is not configured, CSR (Cloud Source Repositories) will be used by default. | <pre>object({<br>    repo_type = string # Supported values are: GITHUBv2, GITLABv2 and CSR<br>    # repositories to be created<br>    repositories = map(<br>      object({<br>        repository_name = string<br>        repository_url  = string<br>      })<br>    )<br>    # Credential Config for each repository type<br>    github_secret_id                            = optional(string)<br>    github_app_id_secret_id                     = optional(string)<br>    gitlab_read_authorizer_credential_secret_id = optional(string)<br>    gitlab_authorizer_credential_secret_id      = optional(string)<br>    gitlab_webhook_secret_id                    = optional(string)<br>    gitlab_enterprise_host_uri                  = optional(string)<br>    gitlab_enterprise_service_directory         = optional(string)<br>    gitlab_enterprise_ca_certificate            = optional(string)<br>  })</pre> | n/a | yes |
| environment\_names | A list of environment names. | `list(string)` | n/a | yes |
| envs | Environments | <pre>map(object({<br>    network_self_link = string<br>  }))</pre> | n/a | yes |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| region | CI/CD region | `string` | `"us-central1"` | no |
| remote\_state\_bucket | Backend bucket to load Terraform Remote State Data from previous steps. | `string` | n/a | yes |
| team | Example's team name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| test\_scripts | Test configuration shell scripts |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
