# Cymbal Shop Example

The application is a web-based e-commerce app where users can browse items, add them to the cart, and purchase them.

In the developer platform, it is deployed into a single namespace/fleet scope (`cymbalshops`). All the 11 microservices that build this application are deployed through a single `admin` project using Cloud Deploy. This means only one `skaffold.yaml` file is required to deploy all services.

For more information about the Cymbal Bank application, please visit [microservices-demo repository](https://github.com/GoogleCloudPlatform/microservices-demo/tree/v0.10.1).

## Pre-Requisites

This example requires:

1. 1-bootstrap phase executed successfully.
1. 2-multitenant phase executed successfully.
1. 3-fleetscope phase executed successfully.

## Usage

### Deploying with Google Cloud Build

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

#### Ensure the app acronym is present in 2-multitenant `terraform.tfvars` file

1. Navigate to the Multitenant repository and add the value below if it is not present:

    ```diff
    apps = {
    +    "cymbal-shop": {
    +        "acronym" = "cs",
    +    },
        ...
    }
    ```

#### Add Cymbal Shop Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Cymbal Shop namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "cymbalshops"     = "your-cymbalshop-group@yourdomain.com",
         ...
    }
   ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal shop namespaces.'
    git push --set-upstream origin plan
    ```

1. Merge changes to development. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout development
    git merge plan
    git push origin development
    ```

1. Merge changes to nonproduction. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout nonproduction
    git merge development
    git push origin nonproduction
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout production
    git merge nonproduction
    git push origin production
    ```

1. Navigate out of the Fleetscope repository:

    ```bash
    cd ../
    ```

#### Deploy Cymbal shop App Factory

This stage will setup the application admin project, and infrastructure specific projects if created.

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    ```

1. Navigate to the Application Factory repository and add the value below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "cymbal-shop" = {
    +        "cymbalshop" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        },
    +    }
        ...
    }
    ```

1. After the modification, commit changes:

    ```bash
    git commit -am 'Adds Cymbal shop'
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

#### Deploy Cymbal Shop App Infra

This stage will create the CI/CD pipeline for the service, and application specific infrastructure if specified.

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Retrieve Cymbal Shop repository, Admin Project, and Application specific State Bucket that were created on 4-appfactory stage.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export cymbalshop_project=$(terraform output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_admin_project_id"]')
    echo cymbalshop_project=$cymbalshop_project
    export cymbalshop_infra_repo=$(terraform output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_infra_repository_name"]')
    echo cymbalshop_infra_repo=$cymbalshop_infra_repo
    export cymbalshop_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo cymbalshop_statebucket=$cymbalshop_statebucket

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
    gcloud source repos clone $cymbalshop_infra_repo --project=$cymbalshop_project
    ```

1. (GitHub Only) When using GitHub, clone the repository with the following command.

   ```bash
   git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/$cymbalshop_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the repository with the following command.

   ```bash
   git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/$cymbalshop_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    rm -rf $cymbalshop_infra_repo/modules
    cp -R ./terraform-google-enterprise-application/examples/cymbal-shop/5-appinfra/cymbal-shop/cymbalshop/envs $cymbalshop_infra_repo
    rm -rf $cymbalshop_infra_repo/modules
    cp -R ./terraform-google-enterprise-application//5-appinfra/modules $cymbalshop_infra_repo
    cp ./terraform-example-foundation/build/cloudbuild-tf-* $cymbalshop_infra_repo/
    cp ./terraform-example-foundation/build/tf-wrapper.sh $cymbalshop_infra_repo/
    chmod 755 $cymbalshop_infra_repo/tf-wrapper.sh
    cp -RT ./terraform-example-foundation/policy-library/ $cymbalshop_infra_repo/policy-library
    rm -rf $cymbalshop_infra_repo/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $cymbalshop_infra_repo/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$cymbalshop_statebucket/" $cymbalshop_infra_repo/envs/shared/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $cymbalshop_infra_repo/envs/shared/terraform.tfvars
    ```

##### Commit changes to repository

1. Commit files to cymbalshop repository in the plan branch:

    ```bash
    cd $cymbalshop_infra_repo

    git checkout -b plan
    git add .
    git commit -m 'Initialize cymbalshop repo'
    git push --set-upstream origin plan
    ```

1. Merge plan branch to production branch and push to remote:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. You can view the build results on Google Cloud Build at the admin project.

#### Deploy Cymbal Shop App Source

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Clone the `microservices-demo` repository, it contains the cymbal-shop source code:

    ```bash
    git clone --branch v0.10.1 https://github.com/GoogleCloudPlatform/microservices-demo.git cymbal-shop
    ```

1. Navigate to the repository and create main branch on top of the current version:

    ```bash
    cd cymbal-shop
    git checkout -b main
    ```

1. (CSR Only) Add the remote source repository, this repository will host your application source code:

    ```bash
    git remote add google https://source.developers.google.com/p/$cymbalshop_project/r/eab-cymbal-shop-cymbalshop
    ```

1. (GitHub Only) When using GitHub, add the remote source repository with the following command.

   ```bash
   git remote add origin https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-shop-cymbalshop.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repository with the following command.

   ```bash
   git remote add origin https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-shop-cymbalshop.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Overwrite the repository source code with the overlays defined in `examples/cymbal-shop`:

    ```bash
    cp -r ../terraform-google-enterprise-application/examples/cymbal-shop/6-appsource/cymbal-shop/* .
    ```

1. Add changes and commit to the specified remote, this will trigger the associated Cloud Build CI/CD pipeline:

    ```bash
    git add .
    git commit -m "Add Cymbal Shop Code"
    git push google main
    ```

1. You can view the build results on the Cymbal Shop Admin Project.

### Deploying with Terraform Locally

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-google-enterprise-application
└── .
```

#### Ensure the app acronym is present in 2-multitenant `terraform.tfvars` file

1. Navigate to the Multitenant repository and add the value below if it is not present:

    ```diff
    apps = {
    +    "cymbal-shop": {
    +        "acronym" = "cs",
    +    },
        ...
    }
    ```

#### Add Cymbal Shop Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Cymbal Shop namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "cymbalshops"     = "your-cymbalshop-group@yourdomain.com",
         ...
    }
   ```

#### Deploy Cymbal Shop App Factory

1. Add the cymbal shop application to the `terraform.tfvars` file on 4-appfactory:

    ```diff
    applications = {
    +    "cymbal-shop" = {
    +        "cymbalshop" = {
    +           create_infra_project = false
    +           create_admin_project = true
    +        },
    +    }
    ...
    }
   ```

The specified values above will create a sigle `admin` project for cymbal-shop application. In this case, all cymbal-shop microservices CI/CD pipelines will be on the same project.

1. Run `terraform apply` command on `4-appfactory/envs/shared`.

#### Deploy Cymbal Shop App Infra

1. Copy the directories under `examples/cymbal-shop/5-appinfra` to `5-appinfra`.

    ```bash
    APP_INFRA_REPO=$(readlink -f ./terraform-google-enterprise-application/5-appinfra)
    cp -r $APP_INFRA_REPO/../examples/cymbal-shop/5-appinfra/* $APP_INFRA_REPO/apps/
    (cd $APP_INFRA_REPO/apps/cymbal-shop/cymbalshop && rm -rf modules && ln -s ../../../modules modules)
    ```

    > NOTE: This command must be run on the same level as `terraform-google-enterprise-application` directory.

1. Navigate to `terraform-google-enterprise-application/5-appinfra` directory

    ```bash
    cd terraform-google-enterprise-application/5-appinfra
    ```

1. Adjust the `backend.tf` file with values from your environment. Follow the steps below to retrieve the backend and replace the placeholder:

    - Retrieve state bucket from 4-appfactory and update the example with it:

        ```bash
        export cymbalshop_statebucket=$(terraform -chdir=../4-appfactory/envs/shared output -json app-group | jq -r '.["cymbal-shop.cymbalshop"].app_cloudbuild_workspace_state_bucket_name' | sed 's/.*\///')
        echo cymbalshop_statebucket=$cymbalshop_statebucket

        sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$cymbalshop_statebucket/" $APP_INFRA_REPO/apps/cymbal-shop/cymbalshop/envs/shared/backend.tf
        ```

1. Adjust the `terraform.tfvars` file with values from your environment. Follow the steps below to retrieve the state bucket and replace the placeholder:

    - Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

        ```bash
        terraform -chdir="../1-bootstrap/" init
        export remote_state_bucket=$(terraform -chdir="../1-bootstrap/" output -raw state_bucket)
        echo "remote_state_bucket = ${remote_state_bucket}"

        sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-shop/cymbalshop/envs/shared//terraform.tfvars
        ```

1. Navigate to the service path (`5-appinfra/apps/cymbal-shop/cymbalshop/envs/shared`) and run `terraform apply` command.

#### Deploy Cymbal Shop App Source

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-google-enterprise-application
└── .
```

1. Clone the `microservices-demo` repository, it contains the cymbal-shop source code:

    ```bash
    git clone --branch v0.10.1 https://github.com/GoogleCloudPlatform/microservices-demo.git cymbal-shop
    ```

1. Navigate to the repository and create main branch on top of the current version:

    ```bash
    cd cymbal-shop
    git checkout -b main
    ```

1. Retrieve the `admin` project value:

    ```bash
    export cymbalshop_project=$(terraform -chdir=../terraform-google-enterprise-application/4-appfactory/envs/shared output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_admin_project_id"]')
    echo cymbalshop_project=$cymbalshop_project
    ```

1. (CSR Only) Add the remote source repository, this repository will host your application source code:

    ```bash
    git remote add google https://source.developers.google.com/p/$cymbalshop_project/r/eab-cymbal-shop-cymbalshop
    ```

1. (GitHub Only) When using GitHub, add the remote source repository with the following command.

   ```bash
   git remote add origin https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-shop-cymbalshop.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repository with the following command.

   ```bash
   git remote add origin https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-shop-cymbalshop.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Overwrite the repository source code with the overlays defined in `examples/cymbal-shop`:

    ```bash
    cp -r ../terraform-google-enterprise-application/examples/cymbal-shop/6-appsource/cymbal-shop/* .
    ```

1. Add changes and commit to the specified remote, this will trigger the associated Cloud Build CI/CD pipeline:

    ```bash
    git add .
    git commit -m "Add Cymbal Shop Code"
    git push google main
    ```

1. You can view the build results on the Cymbal Shop Admin Project.
