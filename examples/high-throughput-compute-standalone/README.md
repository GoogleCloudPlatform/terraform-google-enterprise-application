
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
ui/.venv/bin/python3 -m pip install --require-hashes -r ui/requirements.txt
```

Run the Gradio dashboard:
```sh
ui/.venv/bin/python3 ui/main.py generated/config.yaml
```

Use port 8080 or preview 8080 in the Cloud Shell (Webpreview). This allows you to load
tests, inspect the jobs from BigQuery (similar to the dashboard), and has some deep
links into the Console.
