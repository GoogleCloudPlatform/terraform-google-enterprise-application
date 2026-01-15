# Example: Getting started with a VLLM model

This guide demonstrates how to deploy a Large Language Model (LLM) using the vLLM serving engine on a Google Kubernetes Engine (GKE) cluster. It is a modified version of the [GKE Inference Gateway tutorial](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/deploy-gke-inference-gateway#create-model-deployment) adapted for Scaffold and the Enterprise Application Blueprint.

It integrates the following components:

* __vLLM:__ For high-throughput model serving.
* __GKE Inference Gateway:__ For managing model endpoints.
* __Model Armor:__ For security and governance of LLM interactions.


## Pre-Requisites

This example is a component of the __Enterprise Application Blueprint__. It assumes you have already provisioned the foundational infrastructure. You must have successfully executed the following phases:

1. __1-bootstrap__ (CI/CD foundations, Binary Authorization image.)
1. __2-multitenant__ (Cluster setup)
1. __3-fleetscope__ (GKE Fleet management, Binary Authorization policy setup)


## Usage

Please note that some steps in this documentation are specific to the selected Git provider. These steps are clearly marked at the beginning of each instruction. For example, if a step applies only to GitHub users, it will be labeled with "(GitHub only)."


### Deploying with Google Cloud Build

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```


#### Ensure the app acronym  is present and release Channel is RAPID in 2-multitenant `terraform.tfvars` file

1. Navigate to the Multitenant repository and add the value below if it is not present:

    ```diff
    apps = {
    +    "llm-model": {
    +        "acronym" = "llm",
    +    },
        ...
    cluster_release_channel = "RAPID"
    }
    ```


1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds LLM model acronym.'
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

1. Navigate out of the Multitenant repository:

    ```bash
    cd ../
    ```

#### Add LLM model Namespace at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the LLM namespaces at `terraform.tfvars`, if the namespace was not created already. Also, disable Multicluster discovery.

    ```diff
    namespace_ids = {
    +    "llm-model"     = "your-llm-team-group@yourdomain.com",
         ...
    enable_multicluster_discovery = false
    }
   ```


1. Commit and push changes. Because the plan branch is not a named environment branch, pushing your plan branch triggers terraform plan but not terraform apply. Review the plan output in your Cloud Build project. <https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID>

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds LLM namespaces, disable multicluster discovery.'
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


#### Deploy LLM Model App Factory

This stage will setup the application admin project, and infrastructure specific projects if created.

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    ```

1. Navigate to the Application Factory repository and add the value below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "llm-model" = {
    +        "llamma-model" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        },
    +    }
        ...
    }
    repositories = {
    +    llamma-model = {
    +    repository_name = "llamma-model-i-r"
    +    repository_url  = "https://<SOURCE-CONTROL-URL>/<USER-ORGANIZATION>/llamma-model-i-r.git"
    +    },
    }
    ```

1. After the modification, commit changes:

    ```bash
    git commit -am 'Adds LLM model'
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

#### Deploy vLLM Application App Infra

This stage will create the CI/CD pipeline for the service, and application specific infrastructure if specified.

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Retrieve LLM repository, Admin Project, and Application specific State Bucket that were created on 4-appfactory stage.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export llm_model_project=$(terraform output -json app-group | jq -r '.["llm-model.llamma-model"]["app_admin_project_id"]')
    echo llm_model_project=$llm_model_project
    export llm_model_infra_repo=$(terraform output -json app-group | jq -r '.["llm-model.llamma-model"]["app_infra_repository_name"]')
    echo llm_model_infra_repo=$llm_model_infra_repo
    export llm_model_statebucket=$(terraform output -json app-group | jq -r '.["llm-model.llamma-model"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo llm_model_statebucket=$llm_model_statebucket

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
    gcloud source repos clone $llm_model_infra_repo --project=$llm_model_project
    ```

1. (GitHub Only) When using GitHub, clone the repository with the following command.

   ```bash
   git clone git@github.com:<GITHUB-OWNER or ORGANIZATION>/$llm_model_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the repository with the following command.

   ```bash
   git clone git@gitlab.com:<GITLAB-GROUP or ACCOUNT>/$llm_model_infra_repo.git
   ```

   > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    rm -rf $llm_model_infra_repo/modules
    cp -R ./terraform-google-enterprise-application/examples/llm-model/5-appinfra/llm-model/llamma-model/envs $llm_model_infra_repo
    rm -rf $llm_model_infra_repo/modules
    cp -R ./terraform-google-enterprise-application/5-appinfra/modules/ $llm_model_infra_repo
    cp ./terraform-example-foundation/build/cloudbuild-tf-* $llm_model_infra_repo/
    cp ./terraform-example-foundation/build/tf-wrapper.sh $llm_model_infra_repo/
    chmod 755 $llm_model_infra_repo/tf-wrapper.sh
    cp -RT ./terraform-example-foundation/policy-library/ $llm_model_infra_repo/policy-library
    rm -rf $llm_model_infra_repo/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $llm_model_infra_repo/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$llm_model_statebucket/" $llm_model_infra_repo/envs/shared/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $llm_model_infra_repo/envs/shared/terraform.tfvars
    ```

##### Commit changes to repository

1. Commit files to LLM model repository in the plan branch:

    ```bash
    cd $llm_model_infra_repo

    git checkout -b plan
    git add .
    git commit -m 'Initialize LLM model repo'
    git push --set-upstream origin plan
    ```

1. Merge plan branch to production branch and push to remote:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. You can view the build results on Google Cloud Build at the admin project.

#### Deploy LLM model App Source

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

A CI/CD pipeline was created for this application on 5-appinfra, it uses Cloud Build to build the docker image and Cloud Deploy to deploy the image to the cluster using skaffold.

1. Clone the CI/CD repository:

    1.1. Source Repository:
        ```bash
        gcloud source repos clone eab-llm-model-llamma-model --project=REPLACE_WITH_ADMIN_PROJECT
        ```

    1.1. Github:
        ```bash
            git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-llm-model-llamma-model.git
        ```

    1.1. Gitlab:
        ```bash
            git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-llm-model-llamma-model.git
        ```


1. Copy the contents of this directory to the repository:

```bash
cp -r ./terraform-google-enterprise-application/6-appsource/llm-model/* eab-llm-model-llamma-model
```

1. Commit changes

```bash
cd eab-llm-model-llamma-model
git checkout -b main
git add .
git commit -m "Add code to cicd repository"
git push origin main
```

1. After pushing the code to the main branch, the CI (build) pipeline will be triggered on the `llm-admin` project under the common folder. You can view the results on the Cloud Build Page.

1. After the CI build successfully runs, it will automatically trigger the CD pipeline using Cloud Deploy on the same project.


### Deploying with Terraform Locally

**IMPORTANT**: The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

#### Ensure the app acronym  is present and release Channel is RAPID in 2-multitenant `terraform.tfvars` file

1. Navigate to the Multitenant repository and add the value below if it is not present:

    ```diff
    apps = {
    +    "llm-model": {
    +        "acronym" = "llm",
    +    },
        ...
    cluster_release_channel = "RAPID"
    }
    ```

1. Run `terraform apply` command on `2-multitenant/envs/development`.
1. Run `terraform apply` command on `2-multitenant/envs/nonproduction`.
1. Run `terraform apply` command on `2-multitenant/envs/production`.

1. Navigate out of the Multitenant repository:

    ```bash
    cd ../
    ```

#### Add LLM model Namespace at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the LLM namespaces at `terraform.tfvars`, if the namespace was not created already. Also, disable Multicluster discovery.

    ```diff
    namespace_ids = {
    +    "llm-model"     = "your-llm-team-group@yourdomain.com",
         ...
    enable_multicluster_discovery = false
    }
   ```


1. Run `terraform apply` command on `3-fleetscope/envs/development`.
1. Run `terraform apply` command on `3-fleetscope/envs/nonproduction`.
1. Run `terraform apply` command on `3-fleetscope/envs/production`.


#### Deploy LLM Model App Factory

This stage will setup the application admin project, and infrastructure specific projects if created.

1. Navigate to Application Factory folder:

    ```bash
    cd 4-appfactory
    ```

1. Navigate to the Application Factory repository and add the value below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "llm-model" = {
    +        "llamma-model" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        },
    +    }
        ...
    }
    repositories = {
    +    llamma-model = {
    +    repository_name = "llamma-model-i-r"
    +    repository_url  = "https://<SOURCE-CONTROL-URL>/<USER-ORGANIZATION>/llamma-model-i-r.git"
    +    },
    }
    ```

1. Run `terraform apply` command on `4-appfactory/envs/shared`.

#### Deploy vLLM Application App Infra

1. Copy the directories under `examples/llm-model/5-appinfra` to `5-appinfra`.

    ```bash
    APP_INFRA_REPO=$(readlink -f ./terraform-google-enterprise-application/5-appinfra)
    cp -r $APP_INFRA_REPO/../examples/llm-model/5-appinfra/* $APP_INFRA_REPO/apps/
    (cd $APP_INFRA_REPO/apps/llm-model/llamma-model && rm -rf modules && ln -s ../../../modules modules)
    ```

    > NOTE: This command must be run on the same level as `terraform-google-enterprise-application` directory.

1. Navigate to `terraform-google-enterprise-application/5-appinfra` directory

    ```bash
    cd terraform-google-enterprise-application/5-appinfra
    ```

1. Adjust the `backend.tf` file with values from your environment. Follow the steps below to retrieve the backend and replace the placeholder:

    - Retrieve state bucket from 4-appfactory and update the example with it:

        ```bash
        export llm_model_statebucket=$(terraform -chdir=../4-appfactory/envs/shared output -json app-group | jq -r '.["llm-model.llamma-model"].app_cloudbuild_workspace_state_bucket_name' | sed 's/.*\///')
        echo llm_model_statebucket=$llm_model_statebucket

        sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$llm_model_statebucket/" $APP_INFRA_REPO/apps/llm-model/llamma-model/envs/shared/backend.tf
        ```

1. Adjust the `terraform.tfvars` file with values from your environment. Follow the steps below to retrieve the state bucket and replace the placeholder:

    - Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

        ```bash
        terraform -chdir="../1-bootstrap/" init
        export remote_state_bucket=$(terraform -chdir="../1-bootstrap/" output -raw state_bucket)
        echo "remote_state_bucket = ${remote_state_bucket}"

        sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/llm-model/llamma-model/envs/shared/terraform.tfvars
        ```

1. Navigate to the service path (`5-appinfra/apps/llm-model/llamma-model/envs/shared`) and run `terraform apply` command.

## Testing deployment

1. Once the CD pipeline successfully runs, you should be able to see a deployment named `openai-app` on your cluster and be able to send request by Load Balancer IP.

    1. Set the following environment variables:

    ```bash
    export CLUSTER_PROJECT=<CLUSTER_PROJECT_ID>
    export CLUSTER_REGION=<CLUSTER_REGION>
    export CLUSTER_ENVIRONMENT="development" # change for your ENVIRONMENT name
    export GATEWAY_NAME=<GATEWAY_NAME>
    export PORT_NUMBER=<PORT_NUMBER> # Use 80 for HTTP
    ```
    1. Get your cluster credentials

    ```bash
    gcloud container fleet memberships get-credentials  cluster-${CLUSTER_REGION}-${CLUSTER_ENVIRONMENT}  --project ${CLUSTER_PROJECT}
    ```

    1. To get the Gateway endpoint, run the following command:

    ```bash
    echo "Waiting for the Gateway IP address..."
    IP=""
    while [ -z "$IP" ]; do
    IP=$(kubectl get gateway/${GATEWAY_NAME} -n llm-model-${CLUSTER_ENVIRONMENT} -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
    if [ -z "$IP" ]; then
        echo "Gateway IP not found, waiting 5 seconds..."
        sleep 5
    fi
    done

    echo "Gateway IP address is: $IP"
    PORT=${PORT_NUMBER}
    ```
    1. To send a request to the /v1/completions endpoint using curl, run the following command:

    ```bash
    curl -i -X POST ${IP}:${PORT}/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
        "model": "Qwen/Qwen2.5-7B-Instruct",
        "messages": [
        {
            "role": "user",
            "content": "What is the best pizza in the world?"
        }
        ],
        "max_tokens": 512,
        "temperature": 0.7
    }'
    ```
