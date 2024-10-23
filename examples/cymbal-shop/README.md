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

The steps below assume that you are checkout out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

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

1. Move out of Fleetscope folder:

    ```bash
    cd ../
    ```

#### Deploy Cymbal shop App Factory

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    ```

1. Navigate to the Application Factory repository and add the value below to the applications variable:

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

The steps below assume that you are checkout out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Retrieve Cymbal Shop repository created on 4-appfactory.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export cymbalshop_project=$(terraform output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_admin_project_id"]')
    echo cymbalshop_project=$cymbalshop_project
    export cymbalshop_repository=$(terraform output -json app-group | jq -r '.["cymbal-shop.cymbalshop"]["app_infra_repository_name"]')
    echo cymbalshop_repository=$cymbalshop_repository
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

1. Clone the repositories for each service and initialized:

    ```bash
    gcloud source repos clone $cymbalshop_repository --project=$cymbalshop_project
    ```

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    cp -R ./terraform-google-enterprise-application/examples/cymbal-shop/5-appinfra/* $cymbalshop_repository
    cp ./terraform-example-foundation/build/cloudbuild-tf-* $cymbalshop_repository/
    cp ./terraform-example-foundation/build/tf-wrapper.sh $cymbalshop_repository/
    chmod 755 $cymbalshop_repository/tf-wrapper.sh
    sed -i'' -e 's/max_depth=1/max_depth=5/' $cymbalshop_repository/tf-wrapper.sh
    cp -RT ./terraform-example-foundation/policy-library/ $cymbalshop_repository/policy-library
    rm -rf $cymbalshop_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $cymbalshop_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$cymbalshop_statebucket/" $cymbalshop_repository/apps/cymbal-shop/cymbalshop/envs/shared/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $cymbalshop_repository/apps/cymbal-shop/cymbalshop/envs/shared/terraform.tvars
    ```

##### Commit changes to repository

1. Commit files to transactionhistory repository a plan branch:

    ```bash
    cd $cymbalshop_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize cymbalshop repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

#### Deploy Cymbal Shop App Source

v0.10.1 https://github.com/GoogleCloudPlatform/microservices-demo.git