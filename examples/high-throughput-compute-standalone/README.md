
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
| additional\_quota\_enabled | Enable quota requests for additional resources | `bool` | `false` | no |
| artifact\_registry\_name | Name of the Artifact Registry repository | `string` | `"research-images"` | no |
| cloudrun\_enabled | Enable Cloud Run deployment alongside GKE | `bool` | `true` | no |
| cluster\_service\_account | Service Account ID for GKE clusters | `string` | `"gke-risk-research-cluster-sa"` | no |
| clusters\_per\_region | Map of regions to number of clusters to create in each (maximum 4 per region) | `map(number)` | <pre>{<br>  "us-central1": 1<br>}</pre> | no |
| deployment\_type | Parallelstore Instance deployment type (SCRATCH or PERSISTENT) | `string` | `"SCRATCH"` | no |
| enable\_csi\_gcs\_fuse | Enable the GCS Fuse CSI Driver | `bool` | `true` | no |
| enable\_csi\_parallelstore | Enable the Parallelstore CSI Driver | `bool` | `true` | no |
| enable\_workload\_identity | Enable Workload Identity for GKE clusters | `bool` | `true` | no |
| gke\_standard\_cluster\_name | Base name for GKE clusters | `string` | `"gke-risk-research"` | no |
| hsn\_bucket | Enable hierarchical namespace GCS buckets | `bool` | `false` | no |
| lustre\_filesystem | The name of the Lustre filesystem | `string` | `"lustre-fs"` | no |
| lustre\_gke\_support\_enabled | Enable GKE support for Lustre instance | `bool` | `true` | no |
| max\_nodes\_ondemand | Maximum number of on-demand nodes | `number` | `1` | no |
| max\_nodes\_spot | Maximum number of spot nodes | `number` | `1` | no |
| min\_nodes\_ondemand | Minimum number of on-demand nodes | `number` | `0` | no |
| min\_nodes\_spot | Minimum number of spot nodes | `number` | `0` | no |
| node\_machine\_type\_ondemand | Machine type for on-demand node pools | `string` | `"e2-standard-2"` | no |
| node\_machine\_type\_spot | Machine type for spot node pools | `string` | `"e2-standard-2"` | no |
| project\_id | The GCP project ID where resources will be created. | `string` | `"YOUR_PROJECT_ID"` | no |
| pubsub\_exactly\_once | Enable Pub/Sub exactly once subscriptions | `bool` | `true` | no |
| quota\_contact\_email | Contact email for quota requests | `string` | `""` | no |
| regions | List of regions where GKE clusters should be created. Used for multi-region deployments. | `list(string)` | <pre>[<br>  "us-central1"<br>]</pre> | no |
| scripts\_output | Output directory for testing scripts | `string` | `"./generated"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"DRY_RUN"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| storage\_capacity\_gib | Capacity in GiB for the selected storage system (Parallelstore or Lustre) | `number` | `null` | no |
| storage\_ip\_range | IP range for Storage peering, in CIDR notation | `string` | `"172.16.0.0/16"` | no |
| storage\_locations | Map of region to location (zone) for storage instances e.g. {"us-central1" = "us-central1-a"} | `map(string)` | `{}` | no |
| storage\_type | The type of storage system to deploy (PARALLELSTORE, LUSTRE, or null for none) | `string` | `null` | no |
| ui\_image\_enabled | Enable or disable the building of the UI image | `bool` | `false` | no |
| vpc\_name | Name of the VPC network to create | `string` | `"research-vpc"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_service\_account | The service account used by GKE clusters |
| get\_credentials | Get Credentials command |
| local\_test\_scripts | Test scripts for running loadtest |
| lookerstudio\_create\_dashboard\_url | Looker Studio template dashboard |
| monitoring\_dashboard\_url | Monitoring dashboard |
| ui\_image | Image for the UI |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
