# 6. Application Source Code pipeline

## Purpose

This folder contains necessary configurations for each of the Cymbal Bank applications.

## Usage

Push the contents of the subfolders to each respective application's source code repository. Separately push the source contents of each application, available in the Cymbal Bank repo on [GitHub](https://github.com/GoogleCloudPlatform/bank-of-anthos/tree/main/src).

The application source code repository was created in the [5-appinfra phase](../5-appinfra/modules/cicd-pipeline/main.tf) and can be found in each appliction's respective app admin project. The app admin projects were created by the [application factory pipeline](../4-factory/modules/app-group-baseline/main.tf).

## Step-by-step

The step below assumes your are on `terraform-google-enterprise-application` repository.

1. Clone the repository

    ```bash
    git clone --branch v0.6.4 https://github.com/GoogleCloudPlatform/bank-of-anthos.git
    ```

1. Navigate into the new repository and create the `main` branch.

    ```bash
    cd bank-of-anthos
    git checkout -b main
    ```

1. Create `BANK_OF_ANTHOS_PATH` and `APP_SOURCE_DIR_PATH` environment variables.

    ```bash
    export BANK_OF_ANTHOS_PATH=$(pwd)
    export APP_SOURCE_DIR_PATH=$(readlink -f ../6-appsource)
    ```

1. Validate `BANK_OF_ANTHOS_PATH` and `APP_SOURCE_DIR_PATH` variables values.

    ```bash
    echo "Bank of Anthos Path: $BANK_OF_ANTHOS_PATH"
    echo "App Source Path: $APP_SOURCE_DIR_PATH"
    ```

1. Run the commands below to update the `bank-of-anthos` codebase with the updated assets:

    - Remove components and frontend:

        ```bash
        rm -rf src/components
        rm -rf src/frontend/k8s
        ```

    - Update database and components assets:

        ```bash
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/ledger/ledger-db/k8s/overlays
        
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/accounts-db/k8s/overlays/* $BANK_OF_ANTHOS_PATH/src/accounts/accounts-db/k8s/overlays

        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/components $BANK_OF_ANTHOS_PATH/src/
        ```

    - Override `skaffold.yaml` files:

        ```bash
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/frontend/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/frontend

        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-ledgerwriter/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-transactionhistory/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-balancereader/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/ledger/balancereader

        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/accounts-userservice/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/userservice
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/accounts-contacts/skaffold.yaml $BANK_OF_ANTHOS_PATH/src/accounts/contacts
        ```
    

    
    - Update `k8s` overlays:

        ```bash
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/frontend/k8s $BANK_OF_ANTHOS_PATH/src/frontend

        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-ledgerwriter/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/ledgerwriter/k8s
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-transactionhistory/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/transactionhistory/k8s
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/ledger-balancereader/k8s/* $BANK_OF_ANTHOS_PATH/src/ledger/balancereader/k8s

        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/accounts-userservice/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/userservice/k8s
        cp -r $APP_SOURCE_DIR_PATH/cymbal-bank/accounts-contacts/k8s/* $BANK_OF_ANTHOS_PATH/src/accounts/contacts/k8s
        ```

    - Create specific assets for `frontend`:

        ```bash
        cp $APP_SOURCE_DIR_PATH/../test/integration/appsource/assets/* $BANK_OF_ANTHOS_PATH/src/frontend/k8s/overlays/development
        ```

    - Add files and commit:

        ``` bash
        git add .
        git commit -m "Override codebase with updated assets"
        ```

1. Fill-in the variables below with your environment project id's:

    ```bash
    export FRONTEND_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    export USER_SERVICE_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    export CONTACTS_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    export BALANCEREADER_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    export LEDGERWRITER_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    export TRANSACTIONHISTORY_ADMIN_PROJECT=<INSERT_YOUR_ENVIRONMENT_VALUE_HERE>
    ```

1. Add remote source repositories.

    ```bash
    git remote add frontend https://source.developers.google.com/p/$FRONTEND_ADMIN_PROJECT/r/eab-cymbal-bank-frontend
    git remote add contacts https://source.developers.google.com/p/$CONTACTS_ADMIN_PROJECT/r/eab-cymbal-bank-accounts-contacts
    git remote add userservice https://source.developers.google.com/p/$USER_SERVICE_ADMIN_PROJECT/r/eab-cymbal-bank-accounts-userservice
    git remote add ledgerwriter https://source.developers.google.com/p/$LEDGERWRITER_ADMIN_PROJECT/r/eab-cymbal-bank-ledger-ledgerwriter
    git remote add transactionhistory https://source.developers.google.com/p/$TRANSACTIONHISTORY_ADMIN_PROJECT/r/eab-cymbal-bank-ledger-transactionhistory
    git remote add balancereader https://source.developers.google.com/p/$BALANCEREADER_ADMIN_PROJECT/r/eab-cymbal-bank-ledger-balancereader
    ```

1. Push `main` branch to each remote:

    ```bash
    for remote in frontend contacts userservice ledgerwriter transactionhistory balancereader; do
        git push $remote main
    done
    ```