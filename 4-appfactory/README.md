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
    ├── cymbal-bank/
    │   ├── accounts-userservice-admin
    │   ├── accounts-contacts-admin
    │   ├── ledger-ledger-writer-admin
    │   └── ...
```

## Usage

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

You can now deploy the into your common folder.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform -chdir=./apps/cymbal-bank init
   terraform -chdir=./apps/cymbal-bank plan
   ```

1. Run `apply`.

   ```bash
   terraform -chdir=./apps/cymbal-bank apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform -chdir=./apps/cymbal-bank plan` before you run `terraform -chdir=./apps/cymbal-bank apply`.
