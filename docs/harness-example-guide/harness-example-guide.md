# Harness Example Guide

The user can choose which environments to deploy (development, nonproduction, and production, up to three environments). Besides that, the user also can choose between a single region network or a multi-region network.

*Note: For this harness guide, the supported regions are currently restricted to `us-central1` and `us-east4`.*

## Network Architecture & IP Allocation

To align with Enterprise networking best practices, this harness automatically provisions distinct, **non-overlapping CIDR blocks** for each environment. This ensures 100% isolation by default, while future-proofing your architecture so that VPC Peering or VPN connections can be established later without IP conflict errors.

The environments use the following IP space configurations:
- **Development:** `10.10.x.x` (Primary) and `10.11.x.x` / `10.12.x.x` (Secondary)
- **Non-Production:** `10.20.x.x` (Primary) and `10.21.x.x` / `10.22.x.x` (Secondary)
- **Production:** `10.30.x.x` (Primary) and `10.31.x.x` / `10.32.x.x` (Secondary)

**Cloud Build Private Worker Pool**
The guide also deploys a dedicated Cloud Build Private Worker Pool with a custom NAT VM to provide secure outbound internet access for your CI/CD pipelines. By default, it uses the IP ranges from **workerpool_peering_address** and **workerpool_nat_subnet_ip** terraform.tfvars variables, with the examples below:
- **Workerpool Peering Address:** `10.3.3.0/24`
- **NAT Proxy Subnet:** `10.1.1.0/24`

*(If these worker pool IPs conflict with your existing corporate network, you can override them in your `terraform.tfvars` file).*

## Pre-requisites

You must have a folder and a project inside of it with the following:

1. A billing account linked;
2. The following services enabled:
   - iam.googleapis.com
   - cloudidentity.googleapis.com
   - cloudbilling.googleapis.com
   - cloudbuild.googleapis.com
3. A service account created on this project;
4. A group created for the deployment;
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
- Clone the `terraform-google-enterprise-application` repository on this directory.

```text
deploy-directory/
└── terraform-google-enterprise-application/
```

- Copy the contents of the [setup](./setup) folder into a new directory named `eab-harness` at the same level as `terraform-google-enterprise-application`.

```text
deploy-directory/
├── eab-harness/
└── terraform-google-enterprise-application/
```

- Rename the file `terraform.tfvars.example` to `terraform.tfvars` on the `eab-harness` folder.
- **Update `terraform.tfvars`**: You must replace all the `"REPLACE_ME"` placeholder values with the actual values from your GCP environment. Review the IP address variables to ensure they do not conflict with your existing networks.
- Access the `eab-harness` folder and run the terraform steps to deploy it.

```bash
cd eab-harness
terraform init
terraform plan
terraform apply
```

### Migrating Terraform State to Remote GCS Backend

After the initial local deployment, you must migrate your local Terraform state to the newly created, CMEK-encrypted remote GCS bucket. This ensures your state is securely stored and accessible by your CI/CD pipelines.

1. Retrieve the name of the newly created GCS bucket:

   ```bash
   export backend_bucket=$(terraform output -raw state_bucket)
   echo "backend_bucket = ${backend_bucket}"
   ```

2. Rename `backend.tf.example` to `backend.tf` and update it with the bucket name:

   ```bash
   mv backend.tf.example backend.tf
   sed -i "s|UPDATE_ME|${backend_bucket}|g" backend.tf
   ```

3. Re-initialize Terraform and type `yes` when prompted to copy the state to Cloud Storage:

   ```bash
   terraform init
   ```

4. (Optional) Run `terraform plan` to verify the state configuration. There should be no changes.

- The terraform output of this step will be used to fill the variables on `global.tfvars` during the helper deployment process.
- Proceed to the instructions of [helper deploy](./../../helpers/eab-deployer/README.md)

---

## Clean Up

If you have deployed the full Enterprise Application Blueprint (EAB) using this harness, you must follow these steps in order to successfully destroy the environment.

### 1. Delete Orphaned MCSD Firewall Rules

The EAB deployment automatically creates Multi-Cluster Service Discovery (MCSD) firewall rules in your network projects. Because these rules are created dynamically outside of the harness Terraform state, they are left behind as "orphans" when you destroy the EAB. **You must delete them manually, otherwise Terraform will fail to destroy the VPC networks.**

Run the following command to find and delete these orphaned rules. To ensure safety, this script is strictly scoped to only search inside projects created by this harness (projects starting with `eab-vpc`) and will only target firewall rules ending in `-mcsd`. It will also prompt you for confirmation before deleting each rule.

```bash
# List all projects whose Project ID starts with "eab-vpc"
for project in $(gcloud projects list --filter="projectId:eab-vpc*" --format="value(projectId)"); do
  echo "Checking project: $project"
  # Find firewall rules ending in -mcsd
  for fw_rule in $(gcloud compute firewall-rules list --project="$project" --filter="name~'-mcsd$'" --format="value(name)"); do
    echo "Found orphaned firewall rule: $fw_rule in project $project"
    read -p "Do you want to delete this firewall rule? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      gcloud compute firewall-rules delete "$fw_rule" --project="$project" --quiet
      echo "Deleted $fw_rule."
    else
      echo "Skipped $fw_rule."
    fi
  done
done
```

### 2. Migrate Terraform State Locally

**CRITICAL:** If you migrated the Terraform state to the remote GCS backend, you MUST migrate it back to your local machine before destroying the infrastructure. Because the Terraform state is stored inside the GCS bucket provisioned by this harness, Terraform will crash if it tries to delete the bucket while it holds the active state lock.

1. Disable the remote backend and pull the state locally:

   ```bash
   mv backend.tf backend.tf.disabled
   terraform init -migrate-state
   # Type 'yes' when prompted to copy the state back locally
   ls -la terraform.tfstate
   ```

### 3. Destroy the Harness

*Note: `project_deletion_policy = "DELETE"`, `tfstate_bucket_force_destroy = true`, and `kms_prevent_destroy = false` must have been set in your `terraform.tfvars` during the `apply` phase for this command to work successfully.*

```bash
terraform destroy
```
