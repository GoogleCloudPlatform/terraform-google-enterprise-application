# Cymbal Bank Examples

This example shows how to deploy Cymbal Bank using the infrastructure created using [Enterprise Application blueprint](https://cloud.google.com/architecture/enterprise-application-blueprint).

For more information about the Cymbal Bank application, please visit [Bank of Anthos repository](https://github.com/GoogleCloudPlatform/bank-of-anthos/blob/v0.6.4).

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

#### Add Cymbal Bank namespaces at Fleetscope repository

1. Navigate to Fleetscope repository and add the Cymbal Bank namespaces at `terraform.tfvars` if they were not created:

   ```hcl
    namespace_ids = {
        "cb-frontend"     = "your-frontend-group@yourdomain.com",
        "cb-accounts"     = "your-accounts-group@yourdomain.com",
        "cb-ledger"       = "your-transactions-group@yourdomain.com"
        ...
    }
   ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal Bank namespaces.'
    git push --set-upstream origin plan
    ```

1. Merge changes to development. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout development
    git merge plan
    git push origin development
    ```

1. Merge changes to nonproduction. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout nonproduction
    git merge development
    git push origin nonproduction
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout production
    git merge nonproduction
    git push origin production
    ```

1. Move out of Fleetscope folder:

    ```bash
    cd ../
    ```

#### Add Cymbal Bank envs at App Factory

1. Copy the `examples/cymbal-bank/4-appfactory` folder content to the repo:

    ```bash
    cp -R terraform-google-enterprise-application/examples/cymbal-bank/4-appfactory/* eab-applicationfactory/4-appfactory/
    ```

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal bank code'
    git push --set-upstream origin plan
    ```

1. Merge changes to development. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout development
    git merge plan
    git push origin development
    ```

1. Merge changes to nonproduction. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout nonproduction
    git merge development
    git push origin nonproduction
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout production
    git merge nonproduction
    git push origin production
    ```

1. Move out of App Factory folder:

    ```bash
    cd ../
    ```

#### Add Cymbal Bank envs at App Infra
// TODO: add steps to copy each service code to each repo created at step 4-appfactory
