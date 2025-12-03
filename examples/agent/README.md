# Capital Agent Example

This example deploys an example of LLM Agent, using Agent Development Kit (ADK) at Enterprise Application Blueprint.

This example is designed to be deployed without Multicluster Discovery, you will need to disable it in `2-multitenant` phase.
It also requires a newer version of Kubernetes installed in your cluster. You can check more of it in the [documentation](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/release-channels#channels).


## Pre-Requisites

This example requires:

1. `jq` installed.
1. [1-bootstrap](../../1-bootstrap/README.md) phase executed successfully.
1. [2-multitenant](../../2-multitenant/README.md) phase executed successfully.
1. [3-fleetscope](../../3-fleetscope/README.md) phase executed successfully.

## Usage

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."

### Managing Infrastructure with Google Cloud Build

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
    + "agent": {
    +        "acronym" = "agt",
    +    },
        ...
    }

    + cluster_release_channel = "RAPID"
    + enable_multicluster_discovery = false
    ```

#### Add Capital Agent Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Capital Agent namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "capital-agent"     = "<your-capital-agent-group>@<YOUR-DOMAIN>.com",
         ...
    }
   ```

1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds Capital Agent namespaces.'
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

#### Deploy Capital Agent App Factory

This stage will setup the application admin project, and infrastructure specific projects if created.

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    ```

1. Navigate to the Application Factory repository and add the value below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "agent" = {
    +        "capital-agent" = {
    +            create_infra_project = false // Configures the application to use shared infrastructure. If set to true, it would provision an additional Google Cloud project intended to host dedicated infrastructure for this app, such as databases or message queues.
    +            create_admin_project = true // Provisions a dedicated Google Cloud project to host the application's administrative resources, including its source code repository and Cloud Build CI/CD pipeline.
    +        },
    +    }
        ...
    }
    ```

1. After the modification, commit changes:

    ```bash
    git commit -am 'Adds Capital Agent'
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

#### Deploy Capital Agent App Infra

This stage will create the CI/CD pipeline for the service, and application specific infrastructure if specified.

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Retrieve Capital Agent repository, Admin Project, and Application specific State Bucket that were created on 4-appfactory stage.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export agent_project=$(terraform output -json app-group | jq -r '.["agent.capital-agent"]["app_admin_project_id"]')
    echo agent_project=$agent_project
    export agent_infra_repo=$(terraform output -json app-group | jq -r '.["agent.capital-agent"]["app_infra_repository_name"]')
    echo agent_infra_repo=$agent_infra_repo
    export agent_statebucket=$(terraform output -json app-group | jq -r '.["agent.capital-agent"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo agent_statebucket=$agent_statebucket

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
    gcloud source repos clone $agent_infra_repo --project=$agent_project
    ```

1. (GitHub Only) When using GitHub, clone the repository with the following command.

   ```bash
   git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/$agent_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the repository with the following command.

   ```bash
   git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/$agent_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    rm -rf $agent_infra_repo/modules
    cp -R ./terraform-google-enterprise-application/examples/agent/5-appinfra/agent/capital-agent/envs $agent_infra_repo
    rm -rf $agent_infra_repo/modules
    cp -R ./terraform-google-enterprise-application//5-appinfra/modules $agent_infra_repo
    cp ./terraform-example-foundation/build/cloudbuild-tf-* $agent_infra_repo/
    cp ./terraform-example-foundation/build/tf-wrapper.sh $agent_infra_repo/
    chmod 755 $agent_infra_repo/tf-wrapper.sh
    cp -RT ./terraform-example-foundation/policy-library/ $agent_infra_repo/policy-library
    rm -rf $agent_infra_repo/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $agent_infra_repo/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$agent_statebucket/" $agent_infra_repo/envs/shared/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $agent_infra_repo/envs/shared/terraform.tfvars
    ```

##### Commit changes to repository

1. Commit files to agent repository in the plan branch:

    ```bash
    cd $agent_infra_repo

    git checkout -b plan
    git add .
    git commit -m 'Initialize agent repo'
    git push --set-upstream origin plan
    ```

1. Merge plan branch to production branch and push to remote:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. You can view the build results on Google Cloud Build at the admin project.

#### Deploy Capital Agent App Source

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. (CSR Only) Add the remote source repository, this repository will host your application source code:

    ```bash
    git remote add google https://source.developers.google.com/p/$agent_project/r/eab-agent-capital-agent
    ```

1. (GitHub Only) When using GitHub, add the remote source repository with the following command.

   ```bash
   git remote add origin https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-agent-capital-agent.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repository with the following command.

   ```bash
   git remote add origin https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-agent-capital-agent.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Overwrite the repository source code with the overlays defined in `examples/agent`:

    ```bash
    cp -r ../terraform-google-enterprise-application/examples/agent/6-appsource/* .
    ```

1. Add changes and commit to the specified remote, this will trigger the associated Cloud Build CI/CD pipeline:

    ```bash
    git add .
    git commit -m "Add Capital Agent Code"
    git push google main
    ```

1. You can view the build results on the Capital Agent Admin Project.

### Managing Infrastructure Locally

This deployment method involves running terraform apply from your local machine to create the foundational infrastructure (projects, networking, and the application's CI/CD pipeline). However, the final deployment of the application source code still uses a GitOps model; you will commit your code and push it to a repository to trigger a remote build and deployment via the Cloud Build pipeline you just created.

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
    + "agent": {
    +        "acronym" = "agt",
    +    },
        ...
    }

    + cluster_release_channel = "RAPID"
    + enable_multicluster_discovery = false
    ```

#### Add Capital Agent Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Capital Agent namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
        namespace_ids = {
    +    "capital-agent"     = "<your-capital-agent-group>@<YOUR-DOMAIN>.com",
         ...
    }
   ```

#### Deploy Capital Agent App Factory

1. Add the Capital Agent application to the `terraform.tfvars` file on 4-appfactory:


    ```diff
    applications = {
    +    "agent" = {
    +        "capital-agent" = {
    +            create_infra_project = false // Configures the application to use shared infrastructure. If set to true, it would provision an additional Google Cloud project intended to host dedicated infrastructure for this app, such as databases or message queues.
    +            create_admin_project = true // Provisions a dedicated Google Cloud project to host the application's administrative resources, including its source code repository and Cloud Build CI/CD pipeline.
    +        },
    +    }
        ...
    }
    ```

The specified values above will create a sigle `admin` project for Capital Agent application.

1. Run `terraform apply` command on `4-appfactory/envs/shared`.

#### Deploy Capital Agent App Infra

1. Copy the directories under `examples/agent/5-appinfra` to `5-appinfra`.

    ```bash
    APP_INFRA_REPO=$(readlink -f ./terraform-google-enterprise-application/5-appinfra)
    cp -r $APP_INFRA_REPO/../examples/agent/5-appinfra/* $APP_INFRA_REPO/apps/
    (cd $APP_INFRA_REPO/apps/agent/capital-agent && rm -rf modules && ln -s ../../../modules modules)
    ```

    > NOTE: This command must be run on the same level as `terraform-google-enterprise-application` directory.

1. Navigate to `terraform-google-enterprise-application/5-appinfra` directory

    ```bash
    cd terraform-google-enterprise-application/5-appinfra
    ```

1. Adjust the `backend.tf` file with values from your environment. Follow the steps below to retrieve the backend and replace the placeholder:

    - Retrieve state bucket from 4-appfactory and update the example with it:

        ```bash
        export agent_statebucket=$(terraform -chdir=../4-appfactory/envs/shared output -json app-group | jq -r '.["agent.capital-agent"].app_cloudbuild_workspace_state_bucket_name' | sed 's/.*\///')
        echo agent_statebucket=$agent_statebucket

        sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$agent_statebucket/" $APP_INFRA_REPO/apps/agent/capital-agent/envs/shared/backend.tf
        ```

1. Adjust the `terraform.tfvars` file with values from your environment. Follow the steps below to retrieve the state bucket and replace the placeholder:

    - Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

        ```bash
        terraform -chdir="../1-bootstrap/" init
        export remote_state_bucket=$(terraform -chdir="../1-bootstrap/" output -raw state_bucket)
        echo "remote_state_bucket = ${remote_state_bucket}"

        sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/agent/capital-agent/envs/shared//terraform.tfvars
        ```

1. Navigate to the service path (`5-appinfra/apps/agent/capital-agent/envs/shared`) and run `terraform apply` command.

#### Deploy Capital Agent App Source

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-google-enterprise-application
└── .
```

1. Retrieve the `admin` project value:

    ```bash
    export agent_project=$(terraform -chdir=../terraform-google-enterprise-application/4-appfactory/envs/shared output -json app-group | jq -r '.["agent.capital-agent"]["app_admin_project_id"]')
    echo agent_project=$agent_project
    ```

1. (CSR Only) Add the remote source repository, this repository will host your application source code:

    ```bash
    git remote add google https://source.developers.google.com/p/$agent_project/r/eab-agent-capital-agent
    ```

1. (GitHub Only) When using GitHub, add the remote source repository with the following command.

   ```bash
   git remote add origin https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-agent-capital-agent.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repository with the following command.

   ```bash
   git remote add origin https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-agent-capital-agent.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Overwrite the repository source code with the overlays defined in `examples/agent`:

    ```bash
    cp -r ../terraform-google-enterprise-application/examples/agent/6-appsource/* .
    ```

1. Add changes and commit to the specified remote, this will trigger the associated Cloud Build CI/CD pipeline:

    ```bash
    git add .
    git commit -m "Add Capital Agent Code"
    git push google main
    ```

1. You can view the build results on the Capital Agent Admin Project.
