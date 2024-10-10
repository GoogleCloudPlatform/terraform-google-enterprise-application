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
        "cb-ledger"       = "your-ledger-group@yourdomain.com"
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
    mkdir ./eab-applicationfactory/envs/
    cp -R ./terraform-google-enterprise-application/examples/cymbal-bank/4-appfactory/envs/* ./eab-applicationfactory/envs/
    cp -R ./terraform-google-enterprise-application/4-appfactory/modules/* ./eab-applicationfactory/modules/
    ```
1. Use `terraform output` to get the state bucket value from 1-bootstrap output and replace the placeholder in `terraform.tfvars`.

   ```bash
   cd eab-applicationfactory
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"

   sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" ./terraform.tfvars

   sed -i'' -e "s/UPDATE_ME/${remote_state_bucket}/" ./envs/shared/backend.tf
   ```

1. Navigate to Application Factory repository and checkout plan branch:

    ```bash
    git checkout plan
    git add .
    git commit -m 'Adds Cymbal bank code'
    git push --set-upstream origin plan
    ```

1. Merge changes to production. Because this is a named environment branch, pushing to this branch triggers both terraform plan and terraform apply. Review the apply output in your Cloud Build project https://console.cloud.google.com/cloud-build/builds;region=DEFAULT_REGION?project=YOUR_CLOUD_BUILD_PROJECT_ID

    ```bash
    git checkout production
    git merge plan
    git push origin production
    ```

1. Move out of App Factory folder:

    ```bash
    cd ../
    ```

#### Add Cymbal Bank envs at App Infra

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
   cd eab-applicationfactory
   export remote_state_bucket=$(terraform -chdir="../terraform-google-enterprise-application/1-bootstrap/" output -raw state_bucket)

   echo "remote_state_bucket = ${remote_state_bucket}"
   ```

1. Move out of directory:

    ```bash
    cd ../
    ```

1. Clone the repositories for each service and initialized:

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

1. Copy terraform code for each service repository and replace backend bucket:

    ```bash
    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/ledger-balancereader/* $balancereader_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $balancereader_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $balancereader_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $balancereader_repository/
    chmod 755 $balancereader_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $balancereader_repository/policy-library
    rm -rf $balancereader_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $balancereader_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$balancereader_statebucket/" $balancereader_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $balancereader_repository/*/*/terraform.tfvars


    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/accounts-userservice/* $userservice_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $userservice_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $userservice_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $userservice_repository/
    chmod 755 $userservice_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $userservice_repository/policy-library
    rm -rf $userservice_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $userservice_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$userservice_statebucket/" $userservice_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $userservice_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/frontend/* $frontend_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $frontend_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $frontend_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $frontend_repository/
    chmod 755 $frontend_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $frontend_repository/policy-library
    rm -rf $frontend_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $frontend_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$frontend_statebucket/" $frontend_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $frontend_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/accounts-contacts/* $contacts_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $contacts_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $contacts_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $contacts_repository/
    chmod 755 $contacts_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $contacts_repository/policy-library
    rm -rf $contacts_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $contacts_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$contacts_statebucket/" $contacts_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $contacts_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/ledger-ledgerwriter/* $ledgerwriter_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $ledgerwriter_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $ledgerwriter_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $ledgerwriter_repository/
    chmod 755 $ledgerwriter_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $ledgerwriter_repository/policy-library
    rm -rf $ledgerwriter_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $ledgerwriter_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$ledgerwriter_statebucket/" $ledgerwriter_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $ledgerwriter_repository/*/*/terraform.tfvars

    cp -R ../terraform-google-enterprise-application/examples/cymbal-bank/5-appinfra/ledger-transactionhistory/* $transactionhistory_repository
    cp -R ../terraform-google-enterprise-application/5-appinfra/modules $transactionhistory_repository
    cp ../terraform-example-foundation/build/cloudbuild-tf-* $transactionhistory_repository/
    cp ../terraform-example-foundation/build/tf-wrapper.sh $transactionhistory_repository/
    chmod 755 $transactionhistory_repository/tf-wrapper.sh
    cp -RT ../terraform-example-foundation/policy-library/ $transactionhistory_repository/policy-library
    rm -rf $transactionhistory_repository/policy-library/policies/constraints/*
    sed -i 's/CLOUDSOURCE/FILESYSTEM/g' $transactionhistory_repository/cloudbuild-tf-*
    sed -i'' -e "s/UPDATE_ME/$ledgerwriter_statebucket/" $ledgerwriter_repository/*/*/backend.tf
    sed -i'' -e "s/REMOTE_STATE_BUCKET/${remote_state_bucket}/" $transactionhistory_repository/*/*/terraform.tfvars
    ```

##### Commit changes for Ledgerwriter service

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

##### Commit changes for Contacts service

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

##### Commit changes for BalanceReader service

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
    git push --set-upstream origin plan
    ```

##### Commit changes for UserService service

1. Commit files to userservice repository a plan branch:

    ```bash
    cd $userservice_repository

    git checkout -b plan
    git add .
    git commit -m 'Initialize userservice repo'
    git push --set-upstream origin plan
    ```

1. Merge plan to production branch:

   ```bash
    git checkout -b production
    git push --set-upstream origin plan
    ```

##### Commit changes for Frontend service

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
    git push --set-upstream origin plan
    ```

##### Commit changes for TransactionHistory service

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
    git push --set-upstream origin plan
    ```

#### Application Source Code pipeline

The step below assumes your are on `terraform-google-enterprise-application` repository.

1. Clone Bank of Anthos repository:

    ```bash
    git clone --branch v0.6.4 https://github.com/GoogleCloudPlatform/bank-of-anthos.git
    ```

1. Create `BANK_OF_ANTHOS_PATH` and `APP_SOURCE_DIR_PATH` environment variables.

    ```bash
    cd bank-of-anthos
    export BANK_OF_ANTHOS_PATH=$(pwd)
    export APP_SOURCE_DIR_PATH=$(readlink -f ../terraform-google-enterprise-application/examples/cymbal-bank/6-appsource)
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
        terraform -chdir="cymbal-bank/balancereader-i-r/envs/shared" init
        export balancereader_project=$(terraform -chdir="cymbal-bank/balancereader-i-r/envs/shared" output -raw service_repository_project_id )
        echo balancereader_project=$balancereader_project
        export balancereader_repository=$(terraform -chdir="cymbal-bank/balancereader-i-r/envs/shared" output -raw  service_repository_name)
        echo balancereader_repository=$balancereader_repository
        ```

    - Transaction History:
        ```bash
        terraform -chdir="cymbal-bank/transactionhistory-i-r/envs/shared" init
        export transactionhistory_project=$(terraform -chdir="cymbal-bank/transactionhistory-i-r/envs/shared" output -raw service_repository_project_id )
        echo transactionhistory_project=$transactionhistory_project
        export transactionhistory_repository=$(terraform -chdir="cymbal-bank/transactionhistory-i-r/envs/shared" output -raw  service_repository_name)
        echo transactionhistory_repository=$transactionhistory_repository
        ```

    - Legderwriter:
        ```bash
        terraform -chdir="cymbal-bank/ledgerwriter-i-r/envs/shared" init
        export ledgerwriter_project=$(terraform -chdir="cymbal-bank/ledgerwriter-i-r/envs/shared" output -raw service_repository_project_id )
        echo ledgerwriter_project=$ledgerwriter_project
        export ledgerwriter_repository=$(terraform -chdir="cymbal-bank/ledgerwriter-i-r/envs/shared" output -raw  service_repository_name)
        echo ledgerwriter_repository=$ledgerwriter_repository
        ```

    - Frontend:
        ```bash
        terraform -chdir="cymbal-bank/frontend-i-r/envs/shared" init
        export frontend_project=$(terraform -chdir="cymbal-bank/frontend-i-r/envs/shared" output -raw service_repository_project_id )
        echo frontend_project=$frontend_project
        export frontend_repository=$(terraform -chdir="cymbal-bank/frontend-i-r/envs/shared" output -raw  service_repository_name)
        echo frontend_repository=$frontend_repository
        ```

    - Contacts:
        ```bash
        terraform -chdir="cymbal-bank/contacts-i-r/envs/shared" init
        export contacts_project=$(terraform -chdir="cymbal-bank/contacts-i-r/envs/shared" output -raw service_repository_project_id )
        echo contacts_project=$contacts_project
        export contacts_repository=$(terraform -chdir="cymbal-bank/contacts-i-r/envs/shared" output -raw  service_repository_name)
        echo contacts_repository=$contacts_repository
        ```

    - User Service:
        ```bash
        terraform -chdir="cymbal-bank/userservice-i-r/envs/shared" init
        export userservice_project=$(terraform -chdir="cymbal-bank/userservice-i-r/envs/shared" output -raw service_repository_project_id )
        echo userservice_project=$userservice_project
        export userservice_repository=$(terraform -chdir="cymbal-bank/userservice-i-r/envs/shared" output -raw  service_repository_name)
        echo userservice_repository=$userservice_repository
        ```

1. Add remote source repositories.

    ```bash
    git remote add frontend https://source.developers.google.com/p/$frontend_project/r/$frontend_repository
    git remote add contacts https://source.developers.google.com/p/$contacts_project/r/$contacts_repository
    git remote add userservice https://source.developers.google.com/p/$userservice_project/r/$userservice_repository
    git remote add ledgerwriter https://source.developers.google.com/p/$ledgerwriter_project/r/$ledgerwriter_repository
    git remote add transactionhistory https://source.developers.google.com/p/$transactionhistory_project/r/$transactionhistory_repository
    git remote add balancereader https://source.developers.google.com/p/$balancereader_project/r/$balancereader_repository
    ```

1. Push `main` branch to each remote:

    ```bash
    for remote in frontend contacts userservice ledgerwriter transactionhistory balancereader; do
        git push $remote main
    done
    ```
