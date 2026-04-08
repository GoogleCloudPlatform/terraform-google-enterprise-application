# Harness Example Guide

The focus of this document is to provide a step-by-step guide to deploy an example of a harness for EAB repository. The user can choose how many environments to deploy, from 1 to 3 being development, nonproduction and production. Besides that, the user also can choose between single region network or multi-region network.

## Pre-requisites

You must have a folder and a project inside of it with the following:
1. billing account linked;
2. services enabled:
    - iam.googleapis.com
    - cloudidentity.googleapis.com
    - cloudbilling.googleapis.com
    - cloudbuild.googleapis.com
3. service account created on this project;
4. group created for the deployment;
    - example: example-name@domain.com

### Authenticate with gcloud

- Authenticate with gcloud:

```bash
gcloud auth login
```

- Make sure you have the project mentioned on the pre-requisites section set on the gcloud and authenticate with the application-default:

```bash
gcloud auth application-default login
```

### Prepare the deploy environment

- Create a directory in the file system to host the Cloud Source repositories that will be created and a copy of the Enterprise Application Blueprint.
- Clone the `terraform-google-enterprise-applications` repository on this directory.

```text
deploy-directory/
└── terraform-google-enterprise-applications
```

- Copy the folder [setup](./setup) as `eab-harness` to the same directory.

```text
deploy-directory/
└── eab-harness
└── terraform-google-enterprise-applications
```

- Rename the file `terraform.tfvars.example` to `terraform.tfvars` on `eab-harness` folder.
- Update `terraform.tfvars` with values from your environment.
- Access the `eab-harness` folder and run the terraform steps to deploy it.

```bash
cd eab-harness
terraform init
terraform plan
terraform apply
```

- The terraform output of this step will be used to fill the variables on `global.tfvars` in helper deploy process.
- Proceed to the instructions of [helper deploy](./../../helpers/eab-deployer/README.md)