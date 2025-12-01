# High Throughput Compute Example

This example shows how to deploy the HTC example using the infrastructure created using [Enterprise Application blueprint](https://cloud.google.com/architecture/enterprise-application-blueprint).

## Overview

This is an example of running a loadtest library on Google Cloud infrastructure.

It will run using GKE horizontal pod autoscaler orchestrated using Pub/Sub. For details on the loadtest library, see
its [README.md](https://github.com/GoogleCloudPlatform/risk-and-research-blueprints/blob/main/examples/risk/loadtest/src/README.md). The same techniques can be used to run any kind of
library that is exposing gRPC.

Cloud Logging, Pub/Sub, Cloud Monitoring, BigQuery, and Looker Studio will all be used
for monitoring the infrastructure as it scales.

## Pre-Requisites

This example requires:

1. 1-bootstrap phase executed successfully.
1. 2-multitenant phase executed successfully.
1. 3-fleetscope phase executed successfully.

## Usage

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."

### Deploying with Google Cloud Build

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

#### Add HTC namespaces at Fleetscope repository

1. Navigate to Fleetscope repository and add the HTC namespaces at `terraform.tfvars` if they were not created:

   ```hcl
    namespace_ids = {
        "htc"     = "your-htc-group@yourdomain.com" # Note: Update with your team's Google Group
    }
   ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds HTC namespaces.'
    git push --set-upstream origin plan
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout production
    git merge plan
    git push origin production
    ```

1. Move out of Fleetscope folder:

    ```bash
    cd ../
    ```

#### Add HTC envs at App Factory

1. Copy the `examples/htc/4-appfactory` folder content to the repo:

    ```bash
    mkdir ./eab-applicationfactory/envs/
    cp -R ./terraform-google-enterprise-application/examples/htc/4-appfactory/envs/* ./eab-applicationfactory/envs/
    cp -R ./terraform-google-enterprise-application/4-appfactory/modules/* ./eab-applicationfactory/modules/
    ```

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   cd eab-applicationfactory
   terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" init
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./terraform.tfvars

   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./envs/production/backend.tf
   ```

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds HTC code'
    git push --set-upstream origin plan
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout production
    git merge plan
    git push origin production
    ```

1. Move out of App Factory folder:

    ```bash
    cd ../
    ```

#### Add HTC envs at App Infra

1. Retrieve HTC repositories created on 4-appfactory.

    ```bash
    cd eab-applicationfactory/envs/production/
    terraform init

    export htc_project=$(terraform output -json app-group | jq -r '.["htc.htc"]["app_admin_project_id"]')
    echo htc_project=$htc_project
    export htc_repository=$(terraform output -json app-group | jq -r '.["htc.htc"]["app_infra_repository_name"]')
    echo htc_repository=$htc_repository
    export htc_statebucket=$(terraform output -json app-group | jq -r '.["htc.htc"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo htc_statebucket=$htc_statebucket
    cd ../../../
    ```

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" init
   export remote_state_bucket=$(terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)
   echo "remote_state_bucket = ${remote_state_bucket}"
   ```

1. (CSR Only) Clone the repositories for each service and initialize:

    ```bash
    mkdir htc
    cd htc
    gcloud source repos clone $htc_repository --project=$htc_project
    ```

1. (GitHub Only) When using GitHub, clone the repositories for each service and initialize with the following commands.

   ```bash
   mkdir htc
   cd htc
   git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/$htc_repository.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.


1. (GitLab Only) When using GitLab, clone the repositories for each service and initialize with the following commands.

   ```bash
   mkdir htc
   cd htc
   git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/$htc_repository.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    rm -rf $htc_repository/modules

    cp -R ../terraform-google-enterprise-application/examples/htc/5-appinfra/htc/* $htc_repository
    rm -rf $htc_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $htc_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $htc_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $htc_repository/
    chmod 755 $htc_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $htc_repository/policy-library
    rm -rf $htc_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $htc_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$htc_statebucket/" $htc_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $htc_repository/*/*/terraform.tfvars

##### Commit changes for HTC service

1. Commit files to htc repository a plan branch:

    ```bash
    cd $htc_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize htc repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

#### Application Source Code pipeline

This section describes how to clone the empty application source repository, copy the example code into it, and push it to trigger the CI/CD pipeline.

1. Retrieve Application Source Repository Details

First, retrieve the names of the source code repository and its Google Cloud project from the App Factory's Terraform state. These were created during the 4-appfactory stage.

    ```bash
    cd eab-applicationfactory/envs/production/
    terraform init
    export app_source_project=$(terraform output -json app-group | jq -r '.["htc.htc"]["app_source_project_id"]')
    echo app_source_project=$app_source_project
    export app_source_repository=$(terraform output -json app-group | jq -r '.["htc.htc"]["app_source_repository_name"]')
    echo app_source_repository=$app_source_repository
    cd ../../../
    ```

1. Clone the empty repository created by the App Factory. (CSR Only)

    ```bash
        gcloud source repos clone $app_source_repository --project=$app_source_project
    ```

1. Clone the empty repository created by the App Factory. (CSR Only)

    ```bash
        git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/$app_source_repository.git
    ```

1. Clone the empty repository created by the App Factory. (Gitlab Only)

    ```bash
        git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/$app_source_repository.git
    ```

1. Copy and Commit the Example Source Code

Define the path to the example source code, copy it into your new repository, and commit the files.

    ```bash
        export APP_SOURCE_DIR_PATH=$(readlink -f ./terraform-google-enterprise-application/examples/htc/6-appsource)
        cd $app_source_repository
        cp -r $APP_SOURCE_DIR_PATH/* ./
        git add .
        git commit -m "Add HTC application source code"
    ```

1. Push to main to Trigger the Pipeline

Push the code to the main branch. This will trigger the Cloud Build pipeline to build and deploy the HTC application.

    ```bash
        git push --set-upstream origin main
    ```
