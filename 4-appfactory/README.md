# 4. Application Factory phase

## Purpose

The application factory creates application project groups, which contain resources responsible for deployment of a single application within the developer platform.

An overview of the application factory pipeline is shown below.
![Enterprise Application application factory diagram](../assets/eab-app-factory.svg)

The application factory creates the following resources as defined in the [`app-group-baseline`](./modules/app-group-baseline/) submodule:

* **Application admin project:** A project dedicated for application administration and management.
* **Application environment projects:** A project for the application for each environment (e.g., development, nonproduction, production).
* **Infrastructure repository:** A Git repository containing the Terraform configuration for the application infrastructure.
* **Application infrastucture pipeline:** A Cloud Build pipeline for deploying the application infrastructure specified as Terraform.

It will also create an Application Folder to group your admin projects under it, for example:

```txt
.
└── fldr-common/
    ├── default-example/
    │   ├── hello-world-admin
    │   └── ...
    ├── cymbal-bank/
    │   ├── accounts-userservice-admin
    │   ├── accounts-contacts-admin
    │   ├── ledger-ledger-writer-admin
    │   └── ...
```

## Usage

#### Cloud Build with Github Pre-requisites

To proceed with github as your git provider you will need:

- An authenticated GitHub account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** [GitHub repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) for each one of the repositories below:
  - Multitenant (`eab-multitenant`)
  - Fleetscope (`eab-fleetscope`)
  - Application Factory (`eab-applicationfactory`)

   > Note: Default names for the repositories are, in sequence: `eab-multitenant`, `eab-fleetscope` and `eab-applicationfactory`; If you choose other names for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.
- [Install Cloud Build App on Github](https://github.com/apps/google-cloud-build). After the installation, take note of the application id, it will be used later.
- [Create Personal Access Token on Github with `repo` and `read:user` (or if app is installed in org use `read:org`)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) - After creating the token in Secret Manager, you will use the secret id in the `terraform.tfvars` file.
- Create a secret for the Github Cloud Build App ID:

   ```bash
   APP_ID_VALUE=<replace_with_app_id>
   printf $APP_ID_VALUE | gcloud secrets create github-app-id --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe github-app-id --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Create a secret for the Github Personal Access Token:

   ```bash
   GITHUB_TOKEN=<replace_with_token>
   printf $GITHUB_TOKEN | gcloud secrets create github-pat --project=$GIT_SECRET_PROJECT --data-file=-
   ```

- Take note of the secret id, it will be used in `terraform.tfvars` later on:

   ```bash
   gcloud secrets describe github-pat --project=$GIT_SECRET_PROJECT --format="value(name)"
   ```

- Populate your `terraform.tfvars` file in `1-bootstrap` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```hcl
   cloudbuildv2_repository_config = {
      repo_type = "GITHUBv2"
      repositories = {
         multitenant = {
            repository_name = "eab-multitenant"
            repository_url  = "https://github.com/your-org/eab-multitenant.git"
         }
         applicationfactory = {
            repository_name = "eab-applicationfactory"
            repository_url  = "https://github.com/your-org/eab-applicationfactory.git"
         }
         fleetscope = {
            repository_name = "eab-fleetscope"
            repository_url  = "https://github.com/your-org/eab-fleetscope.git"
         }
      }
      github_secret_id                            = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/github-pat" # Personal Access Token Secret
      github_app_id_secret_id                     = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/github-app-id" # App ID value secret
   }
   ```

#### Cloud Build with Gitlab Pre-requisites

To proceed with gitlab as your git provider you will need:

- An authenticated Gitlab account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** GitLab repository for each one of the repositories infrastucture repositories that will be created, in this example only a `hello-world` infrastucture repo will be created:
  - Hello World Infrastructure Repository (`hello-world-i-r`)

- An access token with the `api` scope to use for connecting and disconnecting repositories.

- An access token with the `read_api` scope to ensure Cloud Build repositories can access source code in repositories.

- Populate your `terraform.tfvars` file in `1-bootstrap` with the Cloud Build 2nd Gen configuration variable, here is an example:

   ```diff
   cloudbuildv2_repository_config = {
      repo_type = "GITLABv2"
      repositories = {
   +     "hello-world" = {
   +         repository_name = "hello-world-i-r"
   +         repository_url  = "https://gitlab.com/<account or group>/hello-world-i-r.git"
        }
      }
   +  gitlab_authorizer_credential_secret_id         = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-api-token"
   +  gitlab_read_authorizer_credential_secret_id    = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-read-api-token"
   +  gitlab_webhook_secret_id                       = "projects/REPLACE_WITH_PRJ_NUMBER/secrets/gitlab-webhook"
   }
   ```

    > IMPORTANT: The map key must be `SERVICE_NAME`. Where `SERVICE_NAME` is the same name specified in the `applications` variable for the microservice.

- Grant [Secret Manager Admin Role](https://cloud.google.com/iam/docs/understanding-roles#secretmanager.admin) to the Service Account that runs the Pipeline on your Git Credentials Project. You can use the gcloud command below by replacing `GIT_SECRET_PROJECT` with the project that stores your Git credentials and `YOUR-CLOUDBUILD-PROJECT` with the project id that hosts the Cloud Build builds for the `eab-applicationfactory` stage.

    ```bash
    gcloud projects add-iam-policy-binding $GIT_SECRET_PROJECT --role=roles/secretmanager.admin --member=serviceAccount:tf-cb-eab-applicationfactory@YOUR-CLOUDBUILD-PROJECT.iam.gserviceaccount.com
    ```

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

1. Update the file with values for your environment.

   > TIP: To retrieve the remote state bucket variable, you can run `terraform -chdir=../1-bootstrap/ output -raw state_bucket` command.

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
