# Standalone Single-Project Example
The Standalone Single Project Example deploys the core Enterprise Application Blueprint into a single project for the purposes of simplified demonstration.

**Do not use this example for production deployments, as it lacks robust separation of duties and least-privileged permissions present in the standard multi-stage deployment.**

This example creates:

- 2-multitenant
    - GKE cluster(s)
    - Cloud Armor
    - App IP addresses (see below for details)
- 3-Fleetscope
    - Fleet namespace
    - Cloud Source Repo
    - Config Management
    - Service Mesh
    - Multicluster Ingress
    - Multicluster Service
- 5-Appinfra
    - Private Worker Pool
    - Cloud Build Trigger
    - Artifact Registry
    - Cloud Deploy
    - Cloud Deploy Pipelines
    - Cloud Build Service Account
    - Cloud Deploy Service Account
    - Cloud Storage

## Pre-requisites

This examples requires one project already created with the following APIs enabled:

- accesscontextmanager.googleapis.com
- anthos.googleapis.com
- anthosconfigmanagement.googleapis.com
- apikeys.googleapis.com
- certificatemanager.googleapis.com
- cloudbilling.googleapis.com
- cloudbuild.googleapis.com
- clouddeploy.googleapis.com
- cloudfunctions.googleapis.com
- cloudresourcemanager.googleapis.com
- cloudtrace.googleapis.com
- compute.googleapis.com
- container.googleapis.com
- gkehub.googleapis.com
- iam.googleapis.com
- iap.googleapis.com
- mesh.googleapis.com
- monitoring.googleapis.com
- multiclusteringress.googleapis.com
- multiclusterservicediscovery.googleapis.com
- networkmanagement.googleapis.com
- secretmanager.googleapis.com
- servicemanagement.googleapis.com
- servicenetworking.googleapis.com
- serviceusage.googleapis.com
- sqladmin.googleapis.com
- storage-api.googleapis.com
- trafficdirector.googleapis.com

The entity used to deploy this examples must have the following roles at Project level:

- Artifact Registry Admin: `roles/artifactregistry.admin`
- Certificate Manager Owner: `roles/certificatemanager.owner`
- Cloud Build Builder: `roles/cloudbuild.builds.builder`
- Cloud Build Worker Pool Owner: `roles/cloudbuild.workerPoolOwner`
- Cloud Deploy Service Agent: `roles/clouddeploy.serviceAgent`
- Cloud Deploy Admin: `roles/clouddeploy.admin`
- Compute Admin: `roles/compute.admin`
- Network Admin: `roles/compute.networkAdmin `
- Security Admin: `roles/compute.securityAdmin`
- Container Admin: `roles/container.admin  `
- Cluster Admin: `roles/container.clusterAdmin`
- DNS Admin: `roles/dns.admin`
- GKE Hub Admin: `roles/gkehub.editor`
- GKE Hub Scope Admin: `roles/gkehub.scopeAdmin`
- Service Account Admin: `roles/iam.serviceAccountAdmin`
- Service Account User: `roles/iam.serviceAccountUser`
- Logging LogWriter: `roles/logging.logWriter`
- Project IAM Admin: `roles/resourcemanager.projectIamAdmin`
- Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
- Source Repository Admin: `roles/source.admin` (if using CSR)
- Storage Admin: `roles/storage.admin`
- Project AdminL `roles/resourcemanager.projectIamAdmin`
- Viewer: `roles/viewer`

The entity used to deploy this examples must have the following roles at Organization level:

- Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Access Context Manager Policy Admin: `roles/accesscontextmanager.policyAdmin`

This example requires a Single network configured:

- One subnet for Cluster
- One subnet for a NAT
- DNS Policy With inbound fowarding enabled
- A [VM Proxy machine configured for Private Worker Pool](https://cloud.google.com/build/docs/private-pools/access-external-resources-using-static-external-ip#access_external_resources_in_a_private_network)
- [Private Service Connect Configured](https://cloud.google.com/build/docs/private-pools/using-vpc-service-controls)

This examples also require a VPC-SC Perimeter created and [configured with project](https://cloud.google.com/vpc-service-controls/docs/set-up-service-perimeter).

## Usage

the steps below assume that you are checked out on the same level as `terraform-google-enterprise-application` directory:

```txt
.
├── terraform-google-enterprise-application
└── .
```

1. Enter at Single Project example folder:

    ```bash
    cd terraform-google-enterprise-application/examples/standalone_single_project
    ```

1. Update `terraform.tfvars`.

1. Update `5-appinfra.tf` with your repositories info.

1. Run `terraform plan` and check the information

1. Run `terraform apply`.

1. Clone Bank of Anthos repository:

    ```bash
    git clone --branch v0.6.7 https://github.com/GoogleCloudPlatform/bank-of-anthos.git
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


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_level\_name | (VPC-SC) Access Level full name. When providing this variable, additional identities will be added to the access level, these are required to work within an enforced VPC-SC Perimeter. | `string` | `null` | no |
| attestation\_kms\_key | The KMS Key ID to be used by attestor. | `string` | n/a | yes |
| binary\_authorization\_image | The Binary Authorization image to be used to create attestation. | `string` | n/a | yes |
| binary\_authorization\_repository\_id | The Binary Authorization artifact registry where the image to be used to create attestation is stored with format `projects/{{project}}/locations/{{location}}/repositories/{{repository_id}}`. | `string` | n/a | yes |
| bucket\_kms\_key | KMS Key id to be used to encrypt bucket. | `string` | `null` | no |
| logging\_bucket | Bucket to store logging. | `string` | `null` | no |
| project\_id | Google Cloud project ID in which to deploy all example resources | `string` | n/a | yes |
| region | Google Cloud region for deployments | `string` | `"us-central1"` | no |
| service\_perimeter\_mode | (VPC-SC) Service perimeter mode: ENFORCE, DRY\_RUN. | `string` | `"ENFORCE"` | no |
| service\_perimeter\_name | (VPC-SC) Service perimeter name. The created projects in this step will be assigned to this perimeter. | `string` | `null` | no |
| subnetwork\_self\_link | Sub-Network self-link | `string` | n/a | yes |
| teams | A map of string at the format {"namespace" = "groupEmail"} | `map(string)` | n/a | yes |
| workerpool\_id | Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.<br><br>The expected format is:<br>`projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.<br><br>If you are using worker pools from a different project, ensure that you grant the<br>`roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:<br>`service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com` | `string` | `null` | no |
| workerpool\_network\_id | Network id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| acronyms | App Acronyms |
| app\_certificates | App Certificates |
| app\_infos | App infos (name, services, team). |
| app\_ip\_addresses | App IP Addresses |
| clouddeploy\_targets\_names | Cloud deploy targets names. |
| cluster\_membership\_ids | GKE cluster membership IDs |
| cluster\_project\_id | Cluster Project ID |
| cluster\_project\_number | Cluster Project ID |
| cluster\_regions | Regions with clusters |
| cluster\_service\_accounts | The default service accounts used for nodes, if not overridden in node\_pools. |
| cluster\_type | Cluster type |
| env | Environment |
| fleet\_project\_id | Fleet Project ID |
| network\_project\_id | Network Project ID |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
