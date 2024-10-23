# 5. Application Infrastructure pipeline

## Purpose

The application infrastructure pipeline deploys the application-specific CI/CD resources as well as any additional application-specific services, such as databases or other managed services.

An overview of application inrastruction pipeline is shown below, in the context of deploying a new applicaiton across the Enterprise Application blueprint.
![Enterprise Application application infrastructure diagram](../assets/eab-app-deployment.svg)

### Application CI/CD pipeline

The application infrastructure pipeline creates the following resources to establish the application CI/CD pipeline, as defined in the [`cicd-pipeline`](./modules/cicd-pipeline/) submodule:

- Cloud Build trigger
- Artifact Registry repository
- Cloud Deploy pipeline and targets
- Cloud Storage buckets for build cache and other build artifacts
- Custom service accounts and IAM bindings

### Other applicaiton infrastructure

The application infrastructure pipeline can create additional resources on a per-environment basis.

In this example, some services are using the [`alloydb-psc-setup`](.modules/alloydb-psc-setup) submodule for creating an AlloyDB Cluster with Private Service Connect.

You may add additional infrastructure like application-specifc databases or other managed services by creating and invoking new submodules.

## Usage

### Deploying with Google Cloud Build

The steps below assume that you are checkout out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

#### Add Hello World Bank envs at App Infra

1. Retrieve Cymbal Bank repositories created on 4-appfactory.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export helloworld_project=$(terraform output -json app-group | jq -r '.["default-example.hello-world"]["app_admin_project_id"]')
    echo helloworld_project=$helloworld_project
    export helloworld_repository=$(terraform output -json app-group | jq -r '.["default-example.hello-world"]["app_infra_repository_name"]')
    echo helloworld_repository=$helloworld_repository
    export helloworld_statebucket=$(terraform output -json app-group | jq -r '.["default-example.hello-world"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo helloworld_statebucket=$helloworld_statebucket

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
    gcloud source repos clone $helloworld_repository --project=$helloworld_project
    ```

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    cp -R ./terraform-google-enterprise-application/5-appinfra/* $helloworld_repository
    mv $helloworld_repository/apps/default-example/hello-world/envs/shared/terraform.example.tfvars $helloworld_repository/apps/default-example/hello-world/envs/shared/terraform.tvars
    cp ./terraform-example-foundation/build/cloudbuild-tf-* $helloworld_repository/
    cp ./terraform-example-foundation/build/tf-wrapper.sh $helloworld_repository/
    chmod 755 $helloworld_repository/tf-wrapper.sh
    sed -i'' -e 's/max_depth=1/max_depth=5/' $helloworld_repository/tf-wrapper.sh
    cp -RT ./terraform-example-foundation/policy-library/ $helloworld_repository/policy-library
    rm -rf $helloworld_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $helloworld_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$helloworld_statebucket/" $helloworld_repository/apps/default-example/hello-world/envs/shared/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $helloworld_repository/apps/default-example/hello-world/envs/shared/terraform.tvars
    ```

##### Commit changes to repository

1. Commit files to transactionhistory repository a plan branch:

    ```bash
    cd $helloworld_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize helloworld repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/5-appinfra` folder.

   ```bash
   cd terraform-google-enterprise-application/5-appinfra
   ```

Under the `apps` folder are examples for each of the cymbal bank applications.

1. Change directory into any of these folders to deploy.

```bash
cd apps/default-example/hello-world
```

1. Use example terraform.tfvars and update values from your environment:

```bash
cp envs/shared/terraform.example.tfvars envs/shared/terraform.tfvars
```

1. Update the configuration with values for your environment.

Deploy the `shared` environment first, which contains the application CI/CD pipeline.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform -chdir=./envs/shared init
   terraform -chdir=./envs/shared plan
   ```

1. Run `apply shared`.

   ```bash
   terraform -chdir=./envs/shared apply
   ```

You can now deploy each of your environments (e.g. production).

1. Run `init` and `plan` and review the output.

   ```bash
   terraform -chdir=./envs/production init
   terraform -chdir=./envs/production plan
   ```

1. Run `apply production`.

   ```bash
   terraform -chdir=./envs/production apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform -chdir=./envs/production plan` before you run `terraform apply -chdir=./envs/production`.
