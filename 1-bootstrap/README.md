# 1. Bootstrap phase

The bootstrap phase establishes the 3 initial pipelines of the Enterprise Application blueprint. These pipelines are:

- the Multitenant Infrastructure pipeline
- the Application Factory
- the Fleet-Scope pipeline

An overview of the deployment methodology for the Enterprise Application blueprint is shown below.
![Enterprise Application blueprint deployment diagram](../assets/eab-deployment.svg)

Each pipeline has the following associated resources:

- 2 Cloud Build triggers
  - 1 trigger to run Terraform Plan commands upon changes to a non-main git branch
  - 1 trigger to run Terraform Apply commands upon changes to the main git branch
- 3 Cloud Storage buckets
  - Terraform State bucket, to store the current state
  - Build Artifacts bucket, to store any artifacts generated during the build process, such as `.tfplan` files
  - Build Logs bucket, to store the logs from the build process
- 1 service account for executing the Cloud Build build process

## Usage

### Pre-requisites

### Cloudbuild with Github Pre-requisites

To proceed with github as your git provider you will need:

- A authenticated GitHub account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** [GitHub repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository) for each one of the repositories below:
  - Multitenant (`eab-multitenant`)
  - Fleetscope (`eab-fleetscope`)
  - Application Factory (`eab-applicationfactory`)

   > Note: Default names for the repositories are, in sequence: `eab-multitenant`, `eab-fleetscope` and `eab-applicationfactory`; If you choose other names for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

- [Install Cloud Build App on Github](https://github.com/apps/google-cloud-build). After the installation, take note of the application id, it will be used in `terraform.tfvars`.
- [Create Personal Access Token on Github with `repo` and `read:user` (or if app is installed in org use `read:org`)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) - After creating the token in secret manager, you will use the secret id in the `terraform.tfvars` file.

### Cloudbuild with Gitlab Pre-requisites

To proceed with gitlab as your git provider you will need:

- A authenticated Gitlab account. The steps in this documentation assumes you have a configured SSH key for cloning and modifying repositories.
- A **private** GitLab repository for each one of the repositories below:
  - Multitenant (`eab-multitenant`)
  - Fleetscope (`eab-fleetscope`)
  - Application Factory (`eab-applicationfactory`)

   > Note: Default names for the repositories are, in sequence: `eab-multitenant`, `eab-fleetscope` and `eab-applicationfactory`; If you choose other names for your repository make sure you update `terraform.tfvars` the repository names under `cloudbuildv2_repository_config` variable.

- An access token with the `api` scope to use for connecting and disconnecting repositories.

- An access token with the `read_api` scope to ensure Cloud Build repositories can access source code in repositories.

### Deploying with Cloud Build

#### Deploying on Enterprise Foundation blueprint

If you have previously deployed the Enterprise Foundation blueprint, create the pipelines in this phase by pushing the contents of this folder to a [workload repo created at stage 5](https://github.com/terraform-google-modules/terraform-example-foundation/blob/master/5-app-infra/README.md). Instead of deploying to multiple environments, create these pipelines in the common folder of the foundation.

Start at "5. Clone the `bu1-example-app` repo". Replace the contents of that repo with the contents of this folder.

### Running Terraform locally

#### Requirements

You will need a project to host your resources, you can manually create it:

```txt
example-organization
└── fldr-common
    └── prj-c-eab-bootstrap
```

#### Step-by-Step

1. The next instructions assume that you are in the `terraform-google-enterprise-application/1-bootstrap` folder.

   ```bash
   cd terraform-google-enterprise-application/1-bootstrap
   ```

1. Rename `terraform.example.tfvars` to `terraform.tfvars`.

   ```bash
   mv terraform.example.tfvars terraform.tfvars
   ```

1. Update the `terraform.tfvars` file with your project id.

You can now deploy the common environment for these pipelines.

1. Run `init` and `plan` and review the output.

   ```bash
   terraform init
   terraform plan
   ```

1. Run `apply`.

   ```bash
   terraform apply
   ```

If you receive any errors or made any changes to the Terraform config or `terraform.tfvars`, re-run `terraform plan` before you run `terraform apply`.

### Updating `backend.tf` files on the repository

Within the repository, you'll find `backend.tf` files that define the GCS bucket for storing the Terraform state. By running the commands below, instances of `UPDATE_ME` placeholders in these files will be automatically replaced with the actual name of your GCS bucket.

1. Running the series of commands below will update the remote state bucket for `backend.tf` files on the repository.

   ```bash
   export backend_bucket=$(terraform output -raw state_bucket)
   echo "backend_bucket = ${backend_bucket}"

   cp backend.tf.example backend.tf
   cd ..

   for i in `find . -name 'backend.tf'`; do sed -i'' -e "s/UPDATE_ME/${backend_bucket}/" $i; done
   ```

1. Re-run `terraform init`. When you're prompted, agree to copy Terraform state to Cloud Storage.

   ```bash
   cd 1-bootstrap

   terraform init
   ```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket\_force\_destroy | When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects. | `bool` | `false` | no |
| bucket\_prefix | Name prefix to use for buckets created. | `string` | `"bkt"` | no |
| common\_folder\_id | Folder ID in which to create all application admin projects, must be prefixed with 'folders/' | `string` | n/a | yes |
| envs | Environments | <pre>map(object({<br>    billing_account    = string<br>    folder_id          = string<br>    network_project_id = string<br>    network_self_link  = string<br>    org_id             = string<br>    subnets_self_links = list(string)<br>  }))</pre> | n/a | yes |
| location | Location for build buckets. | `string` | `"us-central1"` | no |
| project\_id | Project ID for initial resources | `string` | n/a | yes |
| tf\_apply\_branches | List of git branches configured to run terraform apply Cloud Build trigger. All other branches will run plan by default. | `list(string)` | <pre>[<br>  "development",<br>  "nonproduction",<br>  "production"<br>]</pre> | no |
| trigger\_location | Location of for Cloud Build triggers created in the workspace. If using private pools should be the same location as the pool. | `string` | `"global"` | no |

## Outputs

| Name | Description |
|------|-------------|
| artifacts\_bucket | Bucket for storing TF plans |
| cb\_service\_accounts\_emails | Service Accounts for the Multitenant Administration Cloud Build Triggers |
| logs\_bucket | Bucket for storing TF logs |
| project\_id | Project ID |
| source\_repo\_urls | Source repository URLs |
| state\_bucket | Bucket for storing TF state |
| tf\_project\_id | Google Artifact registry terraform project id. |
| tf\_repository\_name | Name of Artifact Registry repository for Terraform image. |
| tf\_tag\_version\_terraform | Docker tag version terraform. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
