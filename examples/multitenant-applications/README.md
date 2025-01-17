# Multitenant Applications

This example demonstrates modifications necessary to deploy two separate application in the cluster, the applications are named `cymbal-bank` and `cymbal-shop`. `cymbal-bank` microservices will be deployed across differente namespaces, to represent different teams, and each microservice will have its own `admin` project, which hosts the CI/CD pipeline for the microservice. `cymbal-shop` microservices will be deployed into a single namespace and all pipelines into a single `admin` project. See the 4-appfactory [terraform.tfvars](./4-appfactory/envs/shared/terraform.tfvars) for more information on how these projects are specified.

The `4-appfactory` directory under this example, contains only a terraform.tfvars file, it represents the variable modifications that are necessary to support both applications on the cluster.

The `5-appinfra` directory contains symbolic links to the `5-appinfra` directories on `examples/cymbal-bank` and `examples/cymbal-shop`. It contains infrastructure specific to the application. On the `envs/shared` a CI/CD pipeline is created using Cloud Build and Cloud Deploy.

The `6-appsource` directory contains symbolic links to the `6-appsource` directories on `examples/cymbal-bank` and `examples/cymbal-shop`. It contains application specific code, this includes custom `cloudbuild.yaml`, `skaffold.yaml` files. The code in this repository will be integrated into `bank-of-anthos` and `microservices-demo` repositories.

## Cymbal Shop Example

The application is a web-based e-commerce app where users can browse items, add them to the cart, and purchase them.

In the developer platform, it is deployed into a single namespace/fleet scope (`cymbalshops`). All the 11 microservices that build this application are deployed through a single `admin` project using Cloud Deploy. This means only one `skaffold.yaml` file is required to deploy all services.

For more information about the Cymbal Bank application, please visit [microservices-demo repository](https://github.com/GoogleCloudPlatform/microservices-demo/tree/v0.10.1).

## Cymbal Bank Example

Cymbal Bank is a web app that simulates a bank's payment processing network. The microservices are divided in three fleet scopes and namespaced and they are deployed through individual `admin` project using Cloud Deploy (1 per microservice) - this means that each microservice will have its own `skaffold.yaml` file.

For more information about the Cymbal Bank application, please visit [Bank of Anthos repository](https://github.com/GoogleCloudPlatform/bank-of-anthos/blob/v0.6.4).

## Pre-Requisites

This example requires:

1. 1-bootstrap phase executed successfully.
1. 2-multitenant phase executed successfully.
1. 3-fleetscope phase executed successfully.

## Usage

### Deploying with Google Cloud Build

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

#### Ensure the app acronym is present in 2-multitenant `terraform.tfvars` file

1. Navigate to the Multitenant repository and add the values below if they are not already present:

    ```diff
    apps = {
    +    "cymbal-shop": {
    +        "acronym" = "cs",
    +    },
    +    "cymbal-bank": {
    +       "acronnym" = "cb",
    +    }
        ...
    }
    ```

#### Add Cymbal Shop and Cymbal Bank Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Cymbal Shop namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "cymbalshops"     = "your-cymbalshop-group@yourdomain.com",
    +    "cb-frontend"     = "your-frontend-group@yourdomain.com",
    +    "cb-accounts"     = "your-accounts-group@yourdomain.com",
    +    "cb-ledger"       = "your-ledger-group@yourdomain.com",
         ...
    }
   ```

#### Deploy 4-appfactory

At this stage, the admin projects, infra projects and source repositories are created.

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    cd eab-applicationfactory
    git checkout plan
    ```

1. Add the values below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "cymbal-bank" = {
    +        "balancereader" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "contacts" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "frontend" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "ledgerwriter" = {
    +            create_infra_project = true
    +            create_admin_project = true
    +        }
    +        "transactionhistory" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "userservice" = {
    +            create_infra_project = true
    +            create_admin_project = true
    +        }
    +    }
    +    "cymbal-shop" = {
    +        "cymbalshop" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        },
    +    }
    +    ...
    }
    ```

1. After the modification, commit changes to the Application Factory repository:

    ```bash
    git checkout plan
    git commit -am 'Adds Cymbal Shop and Cymbal Bank'
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
    cd ..
    ```

#### Deploy 5-appinfra

At this stage, the CI/CD pipeline and app-specific infrastructure are created, this section is separated in two subsections, one for each app.

##### Cymbal Bank 5-appinfra

1. Retrieve Cymbal Bank repositories created on 4-appfactory.

    ```bash
    cd eab-applicationfactory/envs/shared/
    terraform init

    export balancereader_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.balancereader"]["app_admin_project_id"]')
    echo balancereader_project=$balancereader_project
    export balancereader_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.balancereader"]["app_infra_repository_name"]')
    echo balancereader_repository=$balancereader_repository
    export balancereader_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.balancereader"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo balancereader_statebucket=$balancereader_statebucket

    export userservice_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.userservice"]["app_admin_project_id"]')
    echo userservice_project=$userservice_project
    export userservice_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.userservice"]["app_infra_repository_name"]')
    echo userservice_repository=$userservice_repository
    export userservice_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.userservice"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo userservice_statebucket=$userservice_statebucket

    export contacts_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.contacts"]["app_admin_project_id"]')
    echo contacts_project=$contacts_project
    export contacts_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.contacts"]["app_infra_repository_name"]')
    echo contacts_repository=$contacts_repository
    export contacts_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.contacts"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo contacts_statebucket=$contacts_statebucket

    export frontend_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.frontend"]["app_admin_project_id"]')
    echo frontend_project=$frontend_project
    export frontend_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.frontend"]["app_infra_repository_name"]')
    echo frontend_repository=$frontend_repository
    export frontend_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.frontend"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo frontend_statebucket=$frontend_statebucket

    export ledgerwriter_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.ledgerwriter"]["app_admin_project_id"]')
    echo ledgerwriter_project=$ledgerwriter_project
    export ledgerwriter_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.ledgerwriter"]["app_infra_repository_name"]')
    echo ledgerwriter_repository=$ledgerwriter_repository
    export ledgerwriter_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.ledgerwriter"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo ledgerwriter_statebucket=$ledgerwriter_statebucket

    export transactionhistory_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.transactionhistory"]["app_admin_project_id"]')
    echo transactionhistory_project=$transactionhistory_project
    export transactionhistory_repository=$(terraform output -json app-group | jq -r '.["cymbal-bank.transactionhistory"]["app_infra_repository_name"]')
    echo transactionhistory_repository=$transactionhistory_repository
    export transactionhistory_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.transactionhistory"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo transactionhistory_statebucket=$transactionhistory_statebucket
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
    mkdir cymbal-bank
    cd cymbal-bank
    gcloud source repos clone $balancereader_repository --project=$balancereader_project
    gcloud source repos clone $userservice_repository --project=$userservice_project
    gcloud source repos clone $frontend_repository --project=$frontend_project
    gcloud source repos clone $contacts_repository --project=$contacts_project
    gcloud source repos clone $ledgerwriter_repository --project=$ledgerwriter_project
    gcloud source repos clone $transactionhistory_repository --project=$transactionhistory_project
    ```

1. (GitHub Only) When using GitHub, clone the repositories for each service and initialize with the following commands.

    ```bash
    mkdir cymbal-bank
    cd cymbal-bank
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$balancereader_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$userservice_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$frontend_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$contacts_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$ledgerwriter_repository.git
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$transactionhistory_repository.git
    ```

    > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the repositories for each service and initialize with the following commands.

    ```bash
    mkdir cymbal-bank
    cd cymbal-bank
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$balancereader_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$userservice_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$frontend_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$contacts_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$ledgerwriter_repository.git
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$transactionhistory_repository.git
    ```

    > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    rm -rf $frontend_repository/modules
    rm -rf $balancereader_repository/modules
    rm -rf $userservice_repository/modules
    rm -rf $contacts_repository/modules
    rm -rf $ledgerwriter_repository/modules
    rm -rf $transactionhistory_repository/modules

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/ledger-balancereader/* $balancereader_repository
    rm -rf $balancereader_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $balancereader_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $balancereader_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $balancereader_repository/
    chmod 755 $balancereader_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $balancereader_repository/policy-library
    rm -rf $balancereader_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $balancereader_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$balancereader_statebucket/" $balancereader_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $balancereader_repository/*/*/terraform.tfvars


    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/accounts-userservice/* $userservice_repository
    rm -rf $userservice_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $userservice_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $userservice_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $userservice_repository/
    chmod 755 $userservice_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $userservice_repository/policy-library
    rm -rf $userservice_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $userservice_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$userservice_statebucket/" $userservice_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $userservice_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/frontend/* $frontend_repository
    rm -rf $frontend_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $frontend_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $frontend_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $frontend_repository/
    chmod 755 $frontend_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $frontend_repository/policy-library
    rm -rf $frontend_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $frontend_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$frontend_statebucket/" $frontend_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $frontend_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/accounts-contacts/* $contacts_repository
    rm -rf $contacts_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $contacts_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $contacts_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $contacts_repository/
    chmod 755 $contacts_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $contacts_repository/policy-library
    rm -rf $contacts_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $contacts_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$contacts_statebucket/" $contacts_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $contacts_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/ledger-ledgerwriter/* $ledgerwriter_repository
    rm -rf $ledgerwriter_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $ledgerwriter_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $ledgerwriter_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $ledgerwriter_repository/
    chmod 755 $ledgerwriter_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $ledgerwriter_repository/policy-library
    rm -rf $ledgerwriter_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $ledgerwriter_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$ledgerwriter_statebucket/" $ledgerwriter_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $ledgerwriter_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/cymbal-bank/ledger-transactionhistory/* $transactionhistory_repository
    rm -rf $transactionhistory_repository/modules
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $transactionhistory_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $transactionhistory_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $transactionhistory_repository/
    chmod 755 $transactionhistory_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $transactionhistory_repository/policy-library
    rm -rf $transactionhistory_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $transactionhistory_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$ledgerwriter_statebucket/" $ledgerwriter_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $transactionhistory_repository/*/*/terraform.tfvars
    ```

###### Commit changes for Ledgerwriter service

1. Commit files to ledgerwriter repository a plan branch:

    ```bash
    cd $ledgerwriter_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize ledgerwriter repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. Merge plan to nonproduction branch:

   ```bash
    git checkout -b nonproduction
    git push --set-upstream origin nonproduction
    ```

1. Merge plan to development branch:

   ```bash
    git checkout -b development
    git push --set-upstream origin development
    ```

###### Commit changes for Contacts service

1. Commit files to contacts repository a plan branch:

    ```bash
    cd $contacts_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize contacts repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

    ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

###### Commit changes for BalanceReader service

1. Commit files to balancereader repository a plan branch:

    ```bash
    cd $balancereader_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize balancereader repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

###### Commit changes for UserService service

1. Commit files to userservice repository a plan branch:

    ```bash
    cd $ledgerwriter_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize userservice repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

1. Merge plan to nonproduction branch:

   ```bash
    git checkout -b nonproduction
    git push --set-upstream origin nonproduction
    ```

1. Merge plan to development branch:

   ```bash
    git checkout -b development
    git push --set-upstream origin development
    ```

###### Commit changes for Frontend service

1. Commit files to frontend repository a plan branch:

    ```bash
    cd $frontend_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize frontend repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

###### Commit changes for TransactionHistory service

1. Commit files to transactionhistory repository a plan branch:

    ```bash
    cd $transactionhistory_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize transactionhistory repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin production
    ```

##### Cymbal Shop 5-appinfra

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

1. (GitHub Only) When using GitHub, clone the repository for the service and initialize with the following command.

    ```bash
    git clone https://github.com/<GITHUB-OWNER or ORGANIZATION>/$cymbalshop_infra_repo.git
    ```

    > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, clone the repository for the service and initialize with the following command.

    ```bash
    git clone https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/$cymbalshop_infra_repo.git
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

###### Commit changes to repository

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

#### Deploy 6-appsource

At this stage, the CI/CD pipeline will be used with the app-specific repositories that were created in 4-appfactory, this section is separated in two subsections, one for each app.

##### Cymbal Bank 6-appsource

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Clone Bank of Anthos repository:

    ```bash
    git clone --branch v0.6.4 https://github.com/GoogleCloudPlatform/bank-of-anthos.git
    ```

1. Create `BANK_OF_ANTHOS_PATH` and `APP_SOURCE_DIR_PATH` environment variables.

    ```bash
    cd bank-of-anthos
    git checkout -b main
    export BANK_OF_ANTHOS_PATH=$(pwd)
    export APP_SOURCE_DIR_PATH=$(readlink -f ../terraform-google-enterprise-application/examples/cymbal-bank/6-appsource/cymbal-bank)
    ```

1. Run the commands below to update the `bank-of-anthos` codebase with the updated assets:

- Remove components and frontend:

    ```bash
    rm -rf src/components
    rm -rf src/frontend/k8s
    ```

- Update database and components assets:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/ledger-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/ledger/ledger-db/k8s/overlays

    cp -r $APP_SOURCE_DIR_PATH/accounts-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/accounts/accounts-db/k8s/overlays

    cp -r $APP_SOURCE_DIR_PATH/components $BANK_OF_ANTHOS_PATH/src/
    ```

- Override `skaffold.yaml` files:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/frontend/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/frontend

    cp -r $APP_SOURCE_DIR_PATH/ledger-ledgerwriter/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter
    cp -r $APP_SOURCE_DIR_PATH/ledger-transactionhistory/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory
    cp -r $APP_SOURCE_DIR_PATH/ledger-balancereader/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/balancereader

    cp -r $APP_SOURCE_DIR_PATH/accounts-userservice/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/userservice
    cp -r $APP_SOURCE_DIR_PATH/accounts-contacts/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/contacts
    ```

- Update `k8s` overlays:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/frontend/k8s $BANK_OF_ANTHOS_PATH/src/frontend

    cp -r $APP_SOURCE_DIR_PATH/ledger-ledgerwriter/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter/k8s
    cp -r $APP_SOURCE_DIR_PATH/ledger-transactionhistory/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory/k8s
    cp -r $APP_SOURCE_DIR_PATH/ledger-balancereader/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/balancereader/k8s

    cp -r $APP_SOURCE_DIR_PATH/accounts-userservice/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/userservice/k8s
    cp -r $APP_SOURCE_DIR_PATH/accounts-contacts/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/contacts/k8s
    ```

- Create specific assets for `frontend`:

    ```bash
    cp $APP_SOURCE_DIR_PATH/../../../test/integration/appsource/assets/* $BANK_OF_ANTHOS_PATH/src/frontend/k8s/overlays/development
    ```

- Add files and commit:

    ``` bash
    git add .
    git commit -m "Override codebase with updated assets"
    ```

1. Retrieve Cymbal Bank repositories created on 5-appinfra.

    - Balance Reader:

        ```bash
        terraform -chdir="../cymbal-bank/balancereader-i-r/envs/shared" init
        export balancereader_project=$(terraform -chdir="../cymbal-bank/balancereader-i-r/envs/shared" output -raw service_repository_project_id )
        echo balancereader_project=$balancereader_project
        export balancereader_repository=$(terraform -chdir="../cymbal-bank/balancereader-i-r/envs/shared" output -raw  service_repository_name)
        echo balancereader_repository=$balancereader_repository
        ```

    - Transaction History:

        ```bash
        terraform -chdir="../cymbal-bank/transactionhistory-i-r/envs/shared" init
        export transactionhistory_project=$(terraform -chdir="../cymbal-bank/transactionhistory-i-r/envs/shared" output -raw service_repository_project_id )
        echo transactionhistory_project=$transactionhistory_project
        export transactionhistory_repository=$(terraform -chdir="../cymbal-bank/transactionhistory-i-r/envs/shared" output -raw  service_repository_name)
        echo transactionhistory_repository=$transactionhistory_repository
        ```

    - Legderwriter:

        ```bash
        terraform -chdir="../cymbal-bank/ledgerwriter-i-r/envs/shared" init
        export ledgerwriter_project=$(terraform -chdir="../cymbal-bank/ledgerwriter-i-r/envs/shared" output -raw service_repository_project_id )
        echo ledgerwriter_project=$ledgerwriter_project
        export ledgerwriter_repository=$(terraform -chdir="../cymbal-bank/ledgerwriter-i-r/envs/shared" output -raw  service_repository_name)
        echo ledgerwriter_repository=$ledgerwriter_repository
        ```

    - Frontend:

        ```bash
        terraform -chdir="../cymbal-bank/frontend-i-r/envs/shared" init
        export frontend_project=$(terraform -chdir="../cymbal-bank/frontend-i-r/envs/shared" output -raw service_repository_project_id )
        echo frontend_project=$frontend_project
        export frontend_repository=$(terraform -chdir="../cymbal-bank/frontend-i-r/envs/shared" output -raw  service_repository_name)
        echo frontend_repository=$frontend_repository
        ```

    - Contacts:

        ```bash
        terraform -chdir="../cymbal-bank/contacts-i-r/envs/shared" init
        export contacts_project=$(terraform -chdir="../cymbal-bank/contacts-i-r/envs/shared" output -raw service_repository_project_id )
        echo contacts_project=$contacts_project
        export contacts_repository=$(terraform -chdir="../cymbal-bank/contacts-i-r/envs/shared" output -raw  service_repository_name)
        echo contacts_repository=$contacts_repository
        ```

    - User Service:

        ```bash
        terraform -chdir="../cymbal-bank/userservice-i-r/envs/shared" init
        export userservice_project=$(terraform -chdir="../cymbal-bank/userservice-i-r/envs/shared" output -raw service_repository_project_id )
        echo userservice_project=$userservice_project
        export userservice_repository=$(terraform -chdir="../cymbal-bank/userservice-i-r/envs/shared" output -raw  service_repository_name)
        echo userservice_repository=$userservice_repository
        ```

1. (CSR Only) Add remote source repositories.

    ```bash
    git remote add frontend https://source.developers.google.com/p/$frontend_project/r/eab-cymbal-bank-frontend
    git remote add contacts https://source.developers.google.com/p/$contacts_project/r/eab-cymbal-bank-accounts-contacts
    git remote add userservice https://source.developers.google.com/p/$userservice_project/r/eab-cymbal-bank-accounts-userservice
    git remote add ledgerwriter https://source.developers.google.com/p/$ledgerwriter_project/r/eab-cymbal-bank-ledger-ledgerwriter
    git remote add transactionhistory https://source.developers.google.com/p/$transactionhistory_project/r/eab-cymbal-bank-ledger-transactionhistory
    git remote add balancereader https://source.developers.google.com/p/$balancereader_project/r/eab-cymbal-bank-ledger-balancereader
    ```

1. (GitHub Only) When using GitHub, add the remote source repositories with the following commands.

    ```bash
    git remote add frontend https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-frontend.git
    git remote add contacts https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-accounts-contacts.git
    git remote add userservice https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-accounts-userservice.git
    git remote add ledgerwriter https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-ledgerwriter.git
    git remote add transactionhistory https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-transactionhistory.git
    git remote add balancereader https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-balancereader.git
    ```

    > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repositories with the following commands.

    ```bash
    git remote add frontend https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-frontend.git
    git remote add contacts https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-accounts-contacts.git
    git remote add userservice https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-accounts-userservice.git
    git remote add ledgerwriter https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-ledgerwriter.git
    git remote add transactionhistory https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-transactionhistory.git
    git remote add balancereader https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-balancereader.git
    ```

    > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Push `main` branch to each remote:

    ```bash
    for remote in frontend contacts userservice ledgerwriter transactionhistory balancereader; do
        git push $remote main
    done
    ```

##### Cymbal Shop 6-appsource

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

1. Navigate to the Multitenant repository and add the values below if they are not already present:

    ```diff
    apps = {
    +    "cymbal-shop": {
    +        "acronym" = "cs",
    +    },
    +    "cymbal-bank": {
    +       "acronnym" = "cb",
    +    }
        ...
    }
    ```

#### Add Cymbal Shop and Cymbal Bank Namespaces at the Fleetscope repository

The namespaces created at 3-fleetscope will be used in the application kubernetes manifests, when specifying where the workload will run. Typically, the application namespace will be created on 3-fleetscope and specified in 6-appsource.

1. Navigate to Fleetscope repository and add the Cymbal Shop namespaces at `terraform.tfvars`, if the namespace was not created already:

    ```diff
    namespace_ids = {
    +    "cymbalshops"     = "your-cymbalshop-group@yourdomain.com",
    +    "cb-frontend"     = "your-frontend-group@yourdomain.com",
    +    "cb-accounts"     = "your-accounts-group@yourdomain.com",
    +    "cb-ledger"       = "your-ledger-group@yourdomain.com",
         ...
    }
   ```

#### Deploy 4-appfactory

##### Deploy Cymbal Shop App Factory

1. Add the values below to the applications variable on `terraform.tfvars`:

    ```diff
    applications = {
    +    "cymbal-bank" = {
    +        "balancereader" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "contacts" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "frontend" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "ledgerwriter" = {
    +            create_infra_project = true
    +            create_admin_project = true
    +        }
    +        "transactionhistory" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        }
    +        "userservice" = {
    +            create_infra_project = true
    +            create_admin_project = true
    +        }
    +    }
    +    "cymbal-shop" = {
    +        "cymbalshop" = {
    +            create_infra_project = false
    +            create_admin_project = true
    +        },
    +    }
    +    ...
    }
    ```

1. Run `terraform apply` command on `4-appfactory/envs/shared`.

#### Deploy 5-appinfra

##### Deploy Cymbal Shop App Infra

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

##### Add Cymbal Bank envs at App Infra

1. Navigate to application factory

    ```bash
    cd terraform-google-enterprise-application/4-appfactory/envs/shared
    ```

1. Retrieve Cymbal Bank repositories created on 4-appfactory.

    ```bash
    terraform init

    export balancereader_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.balancereader"]["app_admin_project_id"]')
    echo balancereader_project=$balancereader_project
    export balancereader_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.balancereader"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo balancereader_statebucket=$balancereader_statebucket

    export userservice_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.userservice"]["app_admin_project_id"]')
    echo userservice_project=$userservice_project
    export userservice_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.userservice"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo userservice_statebucket=$userservice_statebucket

    export contacts_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.contacts"]["app_admin_project_id"]')
    echo contacts_project=$contacts_project
    export contacts_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.contacts"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo contacts_statebucket=$contacts_statebucket

    export frontend_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.frontend"]["app_admin_project_id"]')
    echo frontend_project=$frontend_project
    export frontend_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.frontend"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo frontend_statebucket=$frontend_statebucket

    export ledgerwriter_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.ledgerwriter"]["app_admin_project_id"]')
    echo ledgerwriter_project=$ledgerwriter_project
    export ledgerwriter_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.ledgerwriter"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo ledgerwriter_statebucket=$ledgerwriter_statebucket

    export transactionhistory_project=$(terraform output -json app-group | jq -r '.["cymbal-bank.transactionhistory"]["app_admin_project_id"]')
    echo transactionhistory_project=$transactionhistory_project
    export transactionhistory_statebucket=$(terraform output -json app-group | jq -r '.["cymbal-bank.transactionhistory"]["app_cloudbuild_workspace_state_bucket_name"]' | sed 's/.*\///')
    echo transactionhistory_statebucket=$transactionhistory_statebucket
    cd ../../../..
    ```

1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" init
   export remote_state_bucket=$(terraform -chdir="./terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)
   echo "remote_state_bucket = ${remote_state_bucket}"
   ```

1. Copy the appinfra from examples to 5-appinfra

    ```bash
    APP_INFRA_REPO=$(readlink -f ./terraform-google-enterprise-application/5-appinfra)
    cp -r $APP_INFRA_REPO/../examples/cymbal-bank/5-appinfra/* $APP_INFRA_REPO/apps/
    ```

1. Adjust the `modules` symbolic links, the command below will adjust the symbolic link for `modules` diretories:

    ```bash
    find $APP_INFRA_REPO/apps/cymbal-bank -type l -name "modules" -exec sh -c 'rm -f "{}" && ln -s "../../../modules" "{}"' \;
    ```

###### Apply changes for Each Service under Shared Environment

All services have common infrastructure under `envs/shared`.

1. Adjust `backend.tf` file and REMOTE_STATE_BUCKET variable for each service:

    ```bash
   # For accounts-contacts
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$contacts_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/accounts-contacts/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/accounts-contacts/*/*/terraform.tfvars

    # For accounts-userservice
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$userservice_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/accounts-userservice/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/accounts-userservice/*/*/terraform.tfvars

    # For frontend
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$frontend_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/frontend/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/frontend/*/*/terraform.tfvars

    # For ledger-balancereader
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$balancereader_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-balancereader/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-balancereader/*/*/terraform.tfvars

    # For ledger-ledgerwriter
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$ledgerwriter_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-ledgerwriter/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-ledgerwriter/*/*/terraform.tfvars

    # For ledger-transactionhistory
    sed -i'' -e "s/UPDATE_INFRA_REPO_STATE/$transactionhistory_statebucket/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-transactionhistory/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $APP_INFRA_REPO/apps/cymbal-bank/ledger-transactionhistory/*/*/terraform.tfvars
    ```

1. Run terraform init, terraform plan and terraform apply command sequence by running the following bash command:

    ```bash
    for service in accounts-contacts accounts-userservice frontend ledger-balancereader ledger-ledgerwriter ledger-transactionhistory;
    do
        cd $APP_INFRA_REPO/apps/cymbal-bank/$service
        terraform -chdir="envs/shared" init
        terraform -chdir="envs/shared" plan
        terraform -chdir="envs/shared" apply
    done
    ```

#### Deploy 6-appsource

##### Deploy Cymbal Shop App Source

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

##### Cymbal Bank Application Source Code pipeline

The steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` and `terraform-example-foundation` directories.

```txt
.
├── terraform-example-foundation
├── terraform-google-enterprise-application
└── .
```

1. Clone Bank of Anthos repository:

    ```bash
    git clone --branch v0.6.4 https://github.com/GoogleCloudPlatform/bank-of-anthos.git
    ```

1. Create `BANK_OF_ANTHOS_PATH` and `APP_SOURCE_DIR_PATH` environment variables.

    ```bash
    cd bank-of-anthos
    git checkout -b main
    export BANK_OF_ANTHOS_PATH=$(pwd)
    export APP_SOURCE_DIR_PATH=$(readlink -f ../terraform-google-enterprise-application/examples/cymbal-bank/6-appsource/cymbal-bank)
    ```

1. Run the commands below to update the `bank-of-anthos` codebase with the updated assets:

- Remove components and frontend:

    ```bash
    rm -rf src/components
    rm -rf src/frontend/k8s
    ```

  - Update database and components assets:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/ledger-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/ledger/ledger-db/k8s/overlays

    cp -r $APP_SOURCE_DIR_PATH/accounts-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/accounts/accounts-db/k8s/overlays

    cp -r $APP_SOURCE_DIR_PATH/components $BANK_OF_ANTHOS_PATH/src/
    ```

  - Override `skaffold.yaml` files:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/frontend/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/frontend

    cp -r $APP_SOURCE_DIR_PATH/ledger-ledgerwriter/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter
    cp -r $APP_SOURCE_DIR_PATH/ledger-transactionhistory/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory
    cp -r $APP_SOURCE_DIR_PATH/ledger-balancereader/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/balancereader

    cp -r $APP_SOURCE_DIR_PATH/accounts-userservice/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/userservice
    cp -r $APP_SOURCE_DIR_PATH/accounts-contacts/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/contacts
    ```

  - Update `k8s` overlays:

    ```bash
    cp -r $APP_SOURCE_DIR_PATH/frontend/k8s $BANK_OF_ANTHOS_PATH/src/frontend

    cp -r $APP_SOURCE_DIR_PATH/ledger-ledgerwriter/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter/k8s
    cp -r $APP_SOURCE_DIR_PATH/ledger-transactionhistory/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory/k8s
    cp -r $APP_SOURCE_DIR_PATH/ledger-balancereader/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/balancereader/k8s

    cp -r $APP_SOURCE_DIR_PATH/accounts-userservice/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/userservice/k8s
    cp -r $APP_SOURCE_DIR_PATH/accounts-contacts/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/contacts/k8s
    ```

  - Create specific assets for `frontend`:

    ```bash
    cp $APP_SOURCE_DIR_PATH/../../../test/integration/appsource/assets/* $BANK_OF_ANTHOS_PATH/src/frontend/k8s/overlays/development
    ```

  - Add files and commit:

    ``` bash
    git add .
    git commit -m "Override codebase with updated assets"
    ```

1. (CSR Only) Add remote source repositories.

    ```bash
    git remote add frontend https://source.developers.google.com/p/$frontend_project/r/eab-cymbal-bank-frontend
    git remote add contacts https://source.developers.google.com/p/$contacts_project/r/eab-cymbal-bank-accounts-contacts
    git remote add userservice https://source.developers.google.com/p/$userservice_project/r/eab-cymbal-bank-accounts-userservice
    git remote add ledgerwriter https://source.developers.google.com/p/$ledgerwriter_project/r/eab-cymbal-bank-ledger-ledgerwriter
    git remote add transactionhistory https://source.developers.google.com/p/$transactionhistory_project/r/eab-cymbal-bank-ledger-transactionhistory
    git remote add balancereader https://source.developers.google.com/p/$balancereader_project/r/eab-cymbal-bank-ledger-balancereader
    ```

1. (GitHub Only) When using GitHub, add the remote source repositories with the following commands.

    ```bash
    git remote add frontend https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-frontend.git
    git remote add contacts https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-accounts-contacts.git
    git remote add userservice https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-accounts-userservice.git
    git remote add ledgerwriter https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-ledgerwriter.git
    git remote add transactionhistory https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-transactionhistory.git
    git remote add balancereader https://github.com/<GITHUB-OWNER or ORGANIZATION>/eab-cymbal-bank-ledger-balancereader.git
    ```

    > NOTE: Make sure to replace `<GITHUB-OWNER or ORGANIZATION>` with your actual GitHub owner or organization name.

1. (GitLab Only) When using GitLab, add the remote source repositories with the following commands.

    ```bash
    git remote add frontend https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-frontend.git
    git remote add contacts https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-accounts-contacts.git
    git remote add userservice https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-accounts-userservice.git
    git remote add ledgerwriter https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-ledgerwriter.git
    git remote add transactionhistory https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-transactionhistory.git
    git remote add balancereader https://gitlab.com/<GITLAB-GROUP or ACCOUNT>/eab-cymbal-bank-ledger-balancereader.git
    ```

    > NOTE: Make sure to replace `<GITLAB-GROUP or ACCOUNT>` with your actual GitLab group or account name.

1. Push `main` branch to each remote:

    ```bash
    for remote in frontend contacts userservice ledgerwriter transactionhistory balancereader; do
        git push $remote main
    done
    ```
