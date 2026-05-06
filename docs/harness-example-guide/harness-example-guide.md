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
└── terraform-google-enterprise-application
```

- Copy the contents of the [setup](./setup) folder into a new directory named `eab-harness` at the same level as `terraform-google-enterprise-application`.

```text
deploy-directory/
├── eab-harness
└── terraform-google-enterprise-application
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

- The terraform output of this step will be used to fill the variables on `global.tfvars` during the helper deployment process.
- Proceed to the instructions of [helper deploy](./../../helpers/eab-deployer/README.md)
