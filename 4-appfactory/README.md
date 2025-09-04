# 4. Application Factory phase

This phase automates the setup of infrastructure and CI/CD pipelines for a single application or microservice on Google Cloud. It creates projects, configures repositories, and sets up Cloud Build triggers for automated builds, testing, and deployments. It supports Cloud Source Repositories (CSR) and 2nd generation Cloud Build repositories through repository connections.

<table>
<tbody>
<tr>
<td><a href="../1-bootstrap">1-bootstrap</a></td>
<td>Bootstraps streamlines the bootstrapping process for Enterprise Applications on Google Cloud Platform (GCP)</td>
</tr>
<tr>
<td><a href="../2-multitenant">2-multitenant</a></td>
<td>Deploys GKE clusters optimized for multi-tenancy within an enterprise environment.</td>
</tr>
<tr>
<td><a href="../3-fleetscope"><span style="white-space: nowrap;">3-fleetscope</span></a></td>
<td>Set-ups Google Cloud Fleet, enabling centralized management of multiple Kubernetes clusters.</td>
</tr>
<tr>
<td>4-appfactory (this file)</td>
<td>Sets up infrastructure and CI/CD pipelines for a single application or microservice on Google Cloud</td>
</tr>
<tr>
<td><a href="../5-appinfra">5-appinfra</a></td>
<td>Set up application infrastructure pipeline aims to establish a streamlined CI/CD workflow for applications, enabling automated deployments to multiple environments (GKE clusters).</td>
</tr>
<tr>
<td><a href="../6-appsource">6-appsource</a></td>
<td>Deploys a modified version of a [simple example](https://github.com/GoogleContainerTools/skaffold/tree/main/examples/getting-started) for skaffold.</td>
</tr>
</tbody>
</table>

## Purpose

This phase streamlines the process of onboarding applications to a Google Cloud environment by automating project creation, repository setup, and CI/CD pipeline configuration. This reduces manual effort, enforces consistent configurations, and accelerates application delivery.

An overview of the application factory pipeline is shown below.

![Enterprise Application application factory diagram](../assets/eab-app-factory.svg)

The application factory creates the following resources as defined in the [`app-group-baseline`](./modules/app-group-baseline/) submodule:

- __Application Admin Project (Optional):__ A new Google Cloud project to host the application's CI/CD pipelines and related resources. This project is created if `create_admin_project` is set to `true`.
- __Application Infrastructure Projects (Optional):__ Environment-specific Google Cloud projects to host the application's infrastructure resources (e.g., GKE clusters, databases). These projects are created if `create_infra_project` is set to `true`.
- __Cloud Source Repository or 2nd Gen Cloud Build Repository:__ Creates a repository for the application's infrastructure code. It defaults to Cloud Source Repository if `cloudbuildv2_repository_config` is not provided, otherwise it uses the specified 2nd Gen Cloud Build repository connection.
- __Cloud Build Triggers:__ Configures Cloud Build triggers to automatically run Terraform plan and apply jobs on code changes in the infrastructure repository.
- __Cloud Build Service Account:__ Creates or uses a Cloud Build service account with the necessary IAM roles to manage infrastructure resources.
- __Cloud Storage Buckets:__ Creates Cloud Storage buckets for storing Cloud Build artifacts, logs, and Terraform state.
- __VPC Service Controls (Optional):__ Configures VPC-SC perimeter and access levels, if `service_perimeter_name` is set.

It will also create an Application Folder to group your admin projects under it, for example:

```txt
.
└── fldr-seed/
  ├── fldr-common/
  │   |── default-example/
  │       ├── hello-world-admin
  │       └── ...
  │   |── cymbal-bank/
  │       ├── accounts-userservice-admin
  │       ├── accounts-contacts-admin
  │       ├── ledger-ledger-writer-admin
  │       └── ...
  ├── fldr-development/
  │   ├── prj-vpc-dev
  │   ├── prj-gke-dev
  │   ├── prj-accounts-userservice
  │   ├── prj-ledger-ledgerwriter
  │   └── ...
  ├── fldr-nonproduction/
  │   ├── prj-vpc-nonprod
  │   ├── prj-gke-dev
  │   ├── prj-accounts-userservice
  │   ├── prj-ledger-ledgerwriter
  │   └── ...
  ├── fldr-prod/
  │   ├── prj-vpc-prod
  │   ├── prj-gke-dev
  │   ├── prj-accounts-userservice
  │   ├── prj-ledger-ledgerwriter
  │   └── ...
  ├── prj-seed
```

## Usage

### Important Considerations:

- __cloudbuildv2_repository_config:__ If using GitHub or GitLab integration, ensure that the appropriate secrets are configured in Secret Manager and that the service account has access to those secrets. Follow the validation rules specified in the variable description. If you omit this variable, ensure that Cloud Source Repositories API is enabled.
- __Network Configuration:__ Ensure that the network project and subnets specified in the envs variable are correctly configured and that the Cloud Build service account has access to them.
- __VPC-SC:__ If using VPC Service Controls, ensure that the `service_perimeter_name` and access_level_name variables are correctly configured. The module will attempt to add the GKE service account to the specified access level. Properly configure ingress and egress rules.

### Git Provider

You have 3 Git provider options for this step: Cloud Source Repositories (CSR), Github, and Gitlab. If you are using Github or Gitlab you will need to take additional steps that are described in the following sections:

- [Cloud Build with Github Pre-requisites](#cloud-build-with-github-pre-requisites)
- [Cloud Build with Gitlab Pre-requisites](#cloud-build-with-gitlab-pre-requisites)

#### Cloud Build with Github Pre-requisites

To proceed with GitHub as your git provider you will need:

- An authenticated GitHub account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
A previously created **private** [GitHub repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) for each one of the repositories connection repositories that will be created, in this example only a `hello-world` connection repo will be created:
  - Hello World Infrastructure Repository (`hello-world-i-r`)
- [Install Cloud Build App on Github](https://github.com/apps/google-cloud-build). After the installation, take note of the application id, it will be used later. Your instalarion id can be foundt in [https://github.com/settings/installations](https://github.com/settings/installations).
- [Create Personal Access Token on Github with `repo` and `read:user` (or if app is installed in org use `read:org`)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) - After creating the token in Secret Manager, you will use the secret id in the `terraform.tfvars` file.

- Populate your `terraform.tfvars` file in `4-appfactory` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```diff
   cloudbuildv2_repository_config = {
      repo_type = "GITHUBv2"
      repositories = {
   +     "hello-world" = {
   +         repository_name = "hello-world-i-r"
   +         repository_url  = "https://github.com/<owner or organization>/hello-world-i-r.git"
        }
      }
   +  github_secret_id = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/github-pat"
   +  github_app_id_secret_id = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/github-app-id"
   }
   ```

    > IMPORTANT: The map key must be `SERVICE_NAME`. Where `SERVICE_NAME` is the same name specified in the `applications` variable for the microservice.

- Grant [Secret Manager Admin Role](https://cloud.google.com/iam/docs/understanding-roles#secretmanager.admin) to the Service Account that runs the Pipeline on your Git Credentials Project. You can use the gcloud command below by replacing `GIT_SECRET_PROJECT` with the project that stores your Git credentials and `YOUR-CLOUDBUILD-PROJECT` with the project id that hosts the Cloud Build builds for the `eab-applicationfactory` stage.

    ```bash
    gcloud projects add-iam-policy-binding $GIT_SECRET_PROJECT --role=roles/secretmanager.admin --member=serviceAccount:tf-cb-eab-applicationfactory@YOUR-CLOUDBUILD-PROJECT.iam.gserviceaccount.com
    ```

#### Cloud Build with Gitlab Pre-requisites

To proceed with Gitlab as your git provider you will need:

- An authenticated Gitlab account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
A previously created **private** GitLab repository for each one of the repositories connection repositories that will be created, in this example only a `hello-world` repository connection will be created:
  - Hello World Infrastructure Repository (`hello-world-i-r`)

- An access token with the `api` scope to use for connecting and disconnecting repositories.

- An access token with the `read_api` scope to ensure Cloud Build repositories can access source code in repositories.

- Populate your `terraform.tfvars` file in `4-appfactory` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```diff
   cloudbuildv2_repository_config = {
      repo_type = "GITLABv2"
      repositories = {
   +     "hello-world" = {
   +         repository_name = "hello-world-i-r"
   +         repository_url  = "https://gitlab.com/<account or group>/hello-world-i-r.git"
        }
      }
   +  gitlab_authorizer_credential_secret_id         = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/gitlab-api-token"
   +  gitlab_read_authorizer_credential_secret_id    = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/gitlab-read-api-token"
   +  gitlab_webhook_secret_id                       = "projects/REPLACE_WITH_SECRET_PRJ_NUMBER/secrets/gitlab-webhook"
   }
   ```

    > IMPORTANT: The map key must be `SERVICE_NAME`. Where `SERVICE_NAME` is the same name specified in the `applications` variable for the microservice.

- Grant [Secret Manager Admin Role](https://cloud.google.com/iam/docs/understanding-roles#secretmanager.admin) to the Service Account that runs the Pipeline on your Git Credentials Project. You can use the gcloud command below by replacing `GIT_SECRET_PROJECT` with the project that stores your Git credentials and `YOUR-CLOUDBUILD-PROJECT` with the project id that hosts the Cloud Build builds for the `eab-applicationfactory` stage.

    ```bash
    gcloud projects add-iam-policy-binding $GIT_SECRET_PROJECT --role=roles/secretmanager.admin --member=serviceAccount:tf-cb-eab-applicationfactory@YOUR-CLOUDBUILD-PROJECT.iam.gserviceaccount.com
    ```

### Worker Pool Requirements

If you are not using Worker Pools you can skip this step. If you are using Worker Pools, an additional step must be taken before deploying.

There is a terraform script that will assign required permissions on the Worker Pool Host Project and requires `var.workerpool_id` to be specified on the 4-appfactory `terraform.tfvars` file. The script is located at [./modules/app-group-baseline/additional_workerpool_permissions.tf.example](./modules/app-group-baseline/additional_workerpool_permissions.tf.example).

1. Enable the permission assignment terraform script on `app-group-baseline` module.

    ```bash
    mv ./modules/app-group-baseline/additional_workerpool_permissions.tf.example ./modules/app-group-baseline/additional_workerpool_permissions.tf
    ```

After renaming the file to `additional_workerpool_permissions.tf`, when you run the pipeline, the required permissions will automatically be assigned on the Worker Pool Host Project.

### Deploying with Google Cloud Build

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."

1. Retrieve Multi-tenant administration project variable value from 1-bootstrap:

    ```bash
    export multitenant_admin_project=$(terraform -chdir=./terraform-google-enterprise-application/1-bootstrap output -raw project_id)

    echo multitenant_admin_project=$multitenant_admin_project
    ```

1. (CSR Only) Clone the infrastructure pipeline repository:

    ```bash
    gcloud source repos clone eab-applicationfactory --project=$multitenant_admin_project
    ```

1. (Github Only) When using Github with Cloud Build, clone the repository with the following command.

    ```bash
    git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/eab-applicationfactory.git
    ```

1. (Gitlab Only) When using Gitlab with Cloud Build, clone the repository with the following command.

    ```bash
    git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/eab-applicationfactory.git
    ```

1. Initialize the git repository, copy `4-appfactory` code into the repository, Cloud Build yaml files and terraform wrapper script:

    ```bash
    cd eab-applicationfactory
    git checkout -b plan

    cp -r ../terraform-google-enterprise-application/4-appfactory/* .
    cp ../terraform-example-foundation/build/cloudbuild-tf-* .
    cp ../terraform-example-foundation/build/tf-wrapper.sh .
    chmod 755 ./tf-wrapper.sh

    cp -RT ../terraform-example-foundation/policy-library/ ./policy-library
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' cloudbuild-tf-*
    ```

1. Disable all policies validation:

    ```bash
    rm -rf policy-library/policies/constraints/*
    ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

    ```bash
    mv terraform.example.tfvars terraform.tfvars
    ```

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./terraform.tfvars
   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./*/*/backend.tf
   ```

1. Update the `terraform.tfvars` file with values for your environment.

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git add .
    git commit -m 'Initialize appfactory repo'
    git push --set-upstream origin plan
    ```

1. Merge changes to production (shared). Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout -b production
    git push origin production
    ```


### Running Terraform locally

1. The next instructions assume that you are in the `terraform-google-enterprise-application/4-appfactory` folder.

   ```bash
   cd ../4-appfactory
   ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

   ```bash
   mv terraform.example.tfvars terraform.tfvars
   ```



1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `backend.tf`.

   ```bash
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./*/*/backend.tf
   ```

You can now deploy the into your common folder.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform -chdir=./envs/shared init
   terraform -chdir=./envs/shared plan
   ```

1. Run `apply`.

   ```bash
   terraform -chdir=./envs/shared apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform -chdir=./envs/shared plan` before you run `terraform -chdir=./envs/shared apply`.

## Troubleshooting

### Project quota exceeded

**Error message:**

```text
Error code 8, message: The project cannot be created because you have exceeded your allotted project quota
```

**Cause:**

This message means you have reached your [project creation quota](https://support.google.com/cloud/answer/6330231).

**Solution:**

In this case, you can use the [Request Project Quota Increase](https://support.google.com/code/contact/project_quota_increase)
form to request a quota increase.

In the support form,
for the field **Email addresses that will be used to create projects**,
use the email address of `projects_step_terraform_service_account_email` that is created by the Terraform Example Foundation 0-bootstrap step.
