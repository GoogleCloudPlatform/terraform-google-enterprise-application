# Multitenant Applications

This example demonstrates modifications necessary to deploy two separate application in the cluster, the applications are named `cymbal-bank` and `cymbal-shop`. `cymbal-bank` microservices will be deployed across differente namespaces, to represent different teams, and each microservice will have its own `admin` project, which hosts the CI/CD pipeline for the microservice. `cymbal-shop` microservices will be deployed into a single namespace and all pipelines into a single `admin` project. See the 4-appfactory [terraform.tfvars](./4-appfactory/envs/shared/terraform.tfvars) for more information on how these projects are specified.

# Cymbal Shop Example

The application is a web-based e-commerce app where users can browse items, add them to the cart, and purchase them.

In the developer platform, it is deployed into a single namespace/fleet scope (`cymbalshops`). All the 11 microservices that build this application are deployed through a single `admin` project using Cloud Deploy. This means only one `skaffold.yaml` file is required to deploy all services.

For more information about the Cymbal Bank application, please visit [microservices-demo repository](https://github.com/GoogleCloudPlatform/microservices-demo/tree/v0.10.1).

# Cymbal Bank Example

Cymbal Bank is a web app that simulates a bank's payment processing network. The microservices are divided in three fleet scopes and namespaced and they are deployed through individual `admin` project using Cloud Deploy (1 per microservice) - this means that each microservice will have its own `skaffold.yaml` file.

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

#### Add Cymbal Bank and Cymbal Shop namespaces at Fleetscope repository

1. Navigate to Fleetscope repository and add the Cymbal Bank namespaces at `terraform.tfvars` if they were not created:

   ```hcl
    namespace_ids = {
        "cb-frontend"     = "your-frontend-group@yourdomain.com",
        "cb-accounts"     = "your-accounts-group@yourdomain.com",
        "cb-ledger"       = "your-ledger-group@yourdomain.com",
        "cymbalshops"     = "your-cymbal-shop-group@yourdomain.com"
        ...
    }
   ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal Bank and Cymbal Shop namespaces.'
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

1. Move out of App Factory folder:

    ```bash
    cd ../
    ```

#### Add Cymbal shop envs at App Factory

1. Copy the `examples/cymbal-shop/4-appfactory` folder content to the repo:

    ```bash
    cp -R terraform-google-enterprise-application/examples/cymbal-shop/4-appfactory/* eab-applicationfactory/4-appfactory/
    ```

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal shop code'
    git push --set-upstream origin plan
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout production
    git merge plan
    git push origin production
    ```

#### Use the `terraform.tfvars` inside this example on the 4-appfactory repository

The [terraform.tfvars](./4-appfactory/terraform.tfvars) contains an example object structure that specifies both the cymbal bank and cymbal shop application creation.

```bash
cp -R terraform-google-enterprise-application/examples/multitenant-applications/4-appfactory/terraform.tfvars eab-applicationfactory/4-appfactory/
```

#### Add Cymbal Bank envs at App Infra

// TODO: add steps to copy each service code to each repo created at step 4-appfactory
