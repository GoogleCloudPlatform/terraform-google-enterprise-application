# 5. Application Infrastructure pipeline

## Purpose
The application infrastructure pipeline deploys the application-specific CI/CD resources as well as any additional application-specific services, such as databases or other managed services.

An overview of application inrastruction pipeline is shown below, in the context of deploying a new applicaiton across the Enterprise Application blueprint.
![Enterprise Application application infrastructure diagram](assets/eab-app-deployment.svg)

### Application CI/CD pipeline
The application infrastructure pipeline creates the following resources to establish the application CI/CD pipeline, as defined in the [`cicd-pipeline`](./modules/cicd-pipeline/) submodule:

- Cloud Build trigger
- Artifact Registry repository
- Cloud Deploy pipeline and targets
- Cloud Storage buckets for build cache and other build artifacts
- Custom service accounts and IAM bindings

### Other applicaiton infrastructure
The application infrastructure pipeline creates additional resources on a per-environment basis as defined in the [`env_baseline`](.modules/env_baseline) submodule. Here, you can define additional infrastructure like application-specifc databases or other managed services.

## Usage
### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/5-appinfra` folder.

   ```bash
   cd terraform-google-enterprise-application/5-appinfra
   ```
Under the `apps` folder are examples for each of the cymbal bank applications.

1. Change directory into any of these folders to deploy.

```
cd apps/accounts-userservice
```

1. Update the configuration with values for your environment.

Deploy the `shared` environment first, which contains the application CI/CD pipeline.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform init -chdir=./envs/shared
   terraform plan -chdir=./envs/shared
   ```

1. Run `apply shared`.

   ```bash
   terraform apply -chdir=./envs/shared
   ```

You can now deploy each of your environments (e.g. production).

1. Run `init` and `plan` and review the output.

   ```bash
   terraform init -chdir=./envs/production
   terraform plan -chdir=./envs/production
   ```

1. Run `apply production`.

   ```bash
   terraform apply -chdir=./envs/production
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform plan -chdir=./envs/production` before you run `terraform apply -chdir=./envs/production`.
