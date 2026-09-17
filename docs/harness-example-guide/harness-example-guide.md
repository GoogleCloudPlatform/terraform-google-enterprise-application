# Single-Project Examples Harness Guide

This guide explains how to prepare all prerequisite Google Cloud infrastructure and deploy the **Single-Project Standalone** reference examples in the Enterprise Application Blueprint (`terraform-google-enterprise-application`).

---

## 1. Overview & Architecture

Single-project standalone examples provide complete, self-contained demonstration sandboxes of the Enterprise Application Blueprint. In this topology, all architectural layers—private GKE clusters, GKE Fleet governance, Cloud Build private worker pools, Artifact Registry, Binary Authorization attestations, Cloud Deploy pipelines, and containerized workloads—are deployed inside a single Google Cloud project.

> [!NOTE]
> Single-project examples are intended for sandbox testing, rapid prototyping, and demonstrations. For production workloads requiring strict separation of duties across multi-tenant environments, refer to the multi-stage foundation blueprint (`terraform-example-foundation`).

### Available Single-Project Reference Examples

| Example | Directory | Workload Type |
| :--- | :--- | :--- |
| **Default Example (Hello World)** | `examples/default-example/standalone-single-project` | Go microservice deployed across Cloud Deploy pipeline stages. |
| **GenAI Agent** | `examples/agent/standalone-single-project` | Python GenAI LLM Agent integrated with Model Armor and HPA. |
| **LLM Model Serving** | `examples/llm-model/standalone-single-project` | vLLM GPU inference service with Prometheus metrics and autoscaling. |
| **Cymbal Bank** | `examples/standalone_single_project` | Multi-tier banking microservices platform (Bank of Anthos). |
| **Confidential Sandbox** | `examples/standalone_single_project_confidential_nodes` | Hardened GKE sandbox running on AMD SEV/SNP Confidential VMs. |

---

## 2. Prerequisites

Before deploying any single-project example, ensure you have the required tools, permissions, and cloud resources.

### 2.1. Required Local Tools

Verify that the following CLI utilities are installed and available in your shell:

- [Terraform](https://developer.hashicorp.com/terraform/install) version **1.5.7** or later.
- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install) version **393.0.0** or later.
- [Git](https://git-scm.com/downloads) version **2.28.0** or later.
- [Go](https://go.dev/doc/install) version **1.25** or later (required when using the `eab-deployer` CLI).
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) to inspect deployed Kubernetes workloads.

Check your installed versions:

```bash
terraform version
gcloud version
git version
go version
kubectl version --client
```

### 2.2. Google Cloud Account & Permissions

1. **Google Cloud Organization & Parent Folder**:
   - A Google Cloud Organization ID (`org_id`).
   - A parent Folder ID (`folder_id`) or organization root under which to provision the sandbox project.

2. **Billing Account**:
   - An active Google Cloud Billing Account linked to your organization.

3. **Deploying Identity IAM Roles**:
   The user or Service Account executing the deployment requires the following roles:
   - **Folder / Organization Level**:
     - `roles/resourcemanager.folderAdmin`
     - `roles/resourcemanager.projectCreator`
     - `roles/billing.user` (or `roles/billing.admin` on the billing account)
     - `roles/compute.xpnAdmin` (if using Shared VPC)
     - `roles/accesscontextmanager.policyAdmin` (optional, if testing with VPC Service Controls)
   - **Project Level (inside the sandbox project)**:
     - `roles/compute.admin` & `roles/compute.networkAdmin`
     - `roles/container.admin` & `roles/container.clusterAdmin`
     - `roles/gkehub.editor` & `roles/gkehub.scopeAdmin`
     - `roles/cloudbuild.workerPoolOwner` & `roles/cloudbuild.builds.builder`
     - `roles/clouddeploy.admin`
     - `roles/artifactregistry.admin`
     - `roles/binaryauthorization.attestorsAdmin`
     - `roles/cloudkms.admin`
     - `roles/secretmanager.admin`
     - `roles/iam.serviceAccountAdmin` & `roles/iam.serviceAccountUser`
     - `roles/serviceusage.serviceUsageAdmin`
     - `roles/storage.admin`

4. **Team / Namespace Groups**:
   - A Cloud Identity or Google Workspace group (for example, `team-apps@yourdomain.com`) to assign as the administrative team identity for Kubernetes namespaces and Fleet scopes.

### 2.3. Authenticate with Google Cloud

Authenticate your user account and Application Default Credentials (ADC):

```bash
gcloud auth login
gcloud auth application-default login
```

Set your quota project:

```bash
gcloud config set billing/quota_project <YOUR_PROJECT_ID>
```

### 2.4. Cloud Source Repositories (CSR) Git Authentication Requirement

If deploying with `repo_type = "CSR"` in `cloudbuildv2_repository_config`, Google Cloud requires manual Git cookie authentication for `source.developers.google.com`:

1. Open [https://source.developers.google.com/new-password](https://source.developers.google.com/new-password) in your browser.
2. Sign in with your Google Cloud deployment identity.
3. Follow the instructions to copy and run the provided authentication script in your terminal, which configures Git cookies in your local `~/.gitcookies` file.

> [!TIP]
> Alternatively, you can configure GitHub (`repo_type = "GITHUBv2"`) or GitLab (`repo_type = "GITLABv2"`) in `cloudbuildv2_repository_config`, or submit application builds directly to Cloud Build via `gcloud builds submit`.


---

## 3. Step-by-Step: Provisioning Prerequisites with the Harness Setup Module

The `docs/harness-example-guide/setup` module automates provisioning the core prerequisites:
- A dedicated Google Cloud Project (`ci-eab-seed-...`).
- Required Google Cloud APIs enabled.
- Cloud KMS keyrings and keys for CMEK storage encryption and Binary Authorization asymmetric attestation signing.
- A Cloud Storage logging bucket and Terraform state bucket.
- (Optional) A pre-provisioned Cloud Build Private Worker Pool with a NAT VM.

### Step 1: Prepare the Working Directory

Create a dedicated working directory to host the repository and harness workspace:

```bash
mkdir -p eab-workspace
cd eab-workspace

# Clone the blueprint repository
git clone https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application.git

# Create a separate harness workspace directory
mkdir -p eab-harness
cp -r terraform-google-enterprise-application/docs/harness-example-guide/setup/* eab-harness/
```

Your directory structure will look like this:

```text
eab-workspace/
├── eab-harness/
└── terraform-google-enterprise-application/
```

### Step 2: Configure `terraform.tfvars`

Navigate into `eab-harness` and copy the example variables file:

```bash
cd eab-harness
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your environment values:

```hcl
org_id          = "123456789012"             // Your numeric Organization ID
folder_id       = "987654321098"             // Parent Folder ID
billing_account = "012345-6789AB-CDEF01"     // Billing Account ID

region = "us-central1"

// Set to true to pre-provision a dedicated Private Worker Pool in this harness
create_workerpool = false

// Sandbox deletion policies (configured for easy teardown in test environments)
project_deletion_policy      = "DELETE"
tfstate_bucket_force_destroy = true
kms_prevent_destroy          = false
```

### Step 3: Initialize and Apply the Harness Setup

Deploy the prerequisite infrastructure:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: (Optional) Migrate Terraform State to GCS Backend

To store the harness Terraform state securely in the newly provisioned GCS bucket:

1. Retrieve the state bucket name:

   ```bash
   export BACKEND_BUCKET=$(terraform output -raw state_bucket)
   echo "State Bucket: ${BACKEND_BUCKET}"
   ```

2. Copy `backend.tf.example` to `backend.tf` and update the bucket name:

   ```bash
   cp backend.tf.example backend.tf
   sed -i "s|UPDATE_ME|${BACKEND_BUCKET}|g" backend.tf
   ```

3. Re-initialize Terraform to migrate state:

   ```bash
   terraform init -migrate-state
   # Type 'yes' when prompted
   ```

---

## 4. Deploying Single-Project Examples

You can deploy single-project examples using either the automated `eab-deployer` CLI helper or directly via Terraform.

### Method A: Automated Deployment with `eab-deployer` CLI (Recommended)

The `eab-deployer` Go CLI automates the multi-step execution lifecycle (building attestation images, configuring Cloud Build triggers, provisioning GKE clusters, and deploying workloads).

#### 1. Compile the Deployer Tool

```bash
cd ../terraform-google-enterprise-application/helpers/eab-deployer
go install
```

#### 2. Configure `global.tfvars`

Return to your root working directory and copy the sample configuration:

```bash
cd ../../
cp terraform-google-enterprise-application/helpers/eab-deployer/global.tfvars.example global.tfvars
```

Populate `global.tfvars` using the outputs from the harness setup:

#### Harness Output to `global.tfvars` Variable Mapping

| `global.tfvars` Variable | Harness Setup Output | Description |
| :--- | :--- | :--- |
| `project_id` | `project_id` | Google Cloud project ID created by the harness. |
| `region` | `region` | Google Cloud deployment region (e.g., `us-central1`). |
| `logging_bucket` | `logging_bucket` | GCS logging bucket name. |
| `bucket_kms_key` | `bucket_kms_key` | KMS Key ID for bucket CMEK encryption. |
| `attestation_kms_key` | `attestation_kms_key` | KMS Key ID for Binary Authorization attestation signing. |
| `workerpool_id` | `workerpool_id` | Private Worker Pool ID (or `null` to let example create one). |
| `network_id` | `network_id` | Peered network self-link (or `null` to let example create one). |
| `eab_code_path` | *N/A (Local path)* | Absolute path to cloned `terraform-google-enterprise-application`. |
| `code_checkout_path` | *N/A (Local path)* | Absolute path to your working directory (e.g., `eab-workspace`). |
| `teams` | *N/A (User group)* | Map of namespace to team group email (e.g., `{"namespace": "team@example.com"}`). |

Example `global.tfvars`:

```hcl
eab_code_path      = "/path/to/eab-workspace/terraform-google-enterprise-application"
code_checkout_path = "/path/to/eab-workspace"

project_id          = "ci-eab-seed-abcd"
region              = "us-central1"
logging_bucket      = "bkt-logging-abcd"
bucket_kms_key      = "projects/ci-eab-seed-abcd/locations/us-central1/keyRings/kms-bucket-encryption/cryptoKeys/bucket"
attestation_kms_key = "projects/ci-eab-seed-abcd/locations/us-central1/keyRings/kms-attestation-sign/cryptoKeys/attestation"

network_id    = null
workerpool_id = null

teams = {
  "hello-world" = "team-dev@yourdomain.com"
}
```

#### 3. Validate Configuration

```bash
$HOME/go/bin/eab-deployer -tfvars_file global.tfvars -validate
```

#### 4. Run Deployment

Deploy the default Hello World example:

```bash
$HOME/go/bin/eab-deployer -tfvars_file global.tfvars -example default-example
```

To deploy other single-project examples, specify the `-example` flag:

- **GenAI Agent:**
  ```bash
  $HOME/go/bin/eab-deployer -tfvars_file global.tfvars -example agent
  ```

- **LLM Model Serving (vLLM):**
  ```bash
  $HOME/go/bin/eab-deployer -tfvars_file global.tfvars -example llm-model
  ```

- **Cymbal Bank Standalone:**
  ```bash
  $HOME/go/bin/eab-deployer -tfvars_file global.tfvars -example standalone_single_project
  ```

---

### Method B: Direct Terraform Deployment

If you prefer deploying directly with Terraform without using the CLI helper:

1. Navigate to the example directory:

   ```bash
   cd terraform-google-enterprise-application/examples/default-example/standalone-single-project
   ```

2. Create and edit `terraform.tfvars`:

   ```hcl
   project_id          = "ci-eab-seed-abcd"
   region              = "us-central1"
   logging_bucket      = "bkt-logging-abcd"
   bucket_kms_key      = "projects/ci-eab-seed-abcd/locations/us-central1/keyRings/kms-bucket-encryption/cryptoKeys/bucket"
   attestation_kms_key = "projects/ci-eab-seed-abcd/locations/us-central1/keyRings/kms-attestation-sign/cryptoKeys/attestation"
   ```

3. Initialize and apply:

   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

---

## 5. Verification & Testing

Once deployment completes, verify the provisioned infrastructure:

### 1. Verify GKE Cluster & Nodes

```bash
# Get credentials for the private GKE cluster
gcloud container clusters get-credentials cluster-us-central1-development \
  --region us-central1 \
  --project <YOUR_PROJECT_ID>

# Verify nodes are running and private
kubectl get nodes -o wide
```

### 2. Verify Cloud Build Triggers & Attestation Builder

```bash
gcloud builds list --project <YOUR_PROJECT_ID> --limit=5
```

### 3. Verify Cloud Deploy Delivery Pipelines

```bash
gcloud deploy delivery-pipelines list \
  --region us-central1 \
  --project <YOUR_PROJECT_ID>
```

### 4. Verify Workload Pods

```bash
kubectl get pods --all-namespaces
```

---

## 6. Clean Up & Teardown

Follow these steps to destroy the environment without leaving orphaned resources.

### Step 1: Clean Up Dynamic GKE & MCSD Firewall Rules

GKE and Multi-Cluster Service Discovery (MCSD) dynamically generate firewall rules that are not recorded in Terraform state. Delete them before running `terraform destroy`:

```bash
PROJECT_ID="<YOUR_PROJECT_ID>"

# Delete dynamic GKE firewall rules
for fw_rule in $(gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="name~'^(gke-|k8s-)'" --format="value(name)"); do
  echo "Deleting GKE firewall rule: ${fw_rule}"
  gcloud compute firewall-rules delete "${fw_rule}" --project="${PROJECT_ID}" --quiet
done

# Delete dynamic MCSD firewall rules
for fw_rule in $(gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="name~'-mcsd$'" --format="value(name)"); do
  echo "Deleting MCSD firewall rule: ${fw_rule}"
  gcloud compute firewall-rules delete "${fw_rule}" --project="${PROJECT_ID}" --quiet
done
```

### Step 2: Destroy the Example Deployment

If you deployed using `eab-deployer`:

```bash
$HOME/go/bin/eab-deployer -tfvars_file global.tfvars -destroy
```

If you deployed directly with Terraform:

```bash
cd terraform-google-enterprise-application/examples/default-example/standalone-single-project
terraform destroy
```

### Step 3: Migrate State Locally Before Destroying Harness

If you enabled the remote GCS state backend for `eab-harness`, migrate it back locally before destroying the bucket:

```bash
cd eab-harness
mv backend.tf backend.tf.disabled
terraform init -migrate-state
# Type 'yes' when prompted
```

### Step 4: Destroy the Harness Setup

Destroy the harness project and foundational resources:

```bash
terraform destroy
```

---

## 7. Troubleshooting

### 7.1. CSR Git Authentication Failure (`400 Invalid authentication credentials`)

**Error message:**
```text
fatal: unable to access 'https://source.developers.google.com/p/<PROJECT_ID>/r/<REPO_NAME>/': The requested URL returned error: 400 Invalid authentication credentials.
Please generate a new identifier: https://source.developers.google.com/new-password
```

**Cause:**
Google Cloud Source Repositories (CSR) requires manually configured Git credentials or cookies when cloning from local environments without an active CSR git credential helper.

**Solutions:**
- **Option 1 (Generate Git Cookie)**:
  1. Navigate to [https://source.developers.google.com/new-password](https://source.developers.google.com/new-password).
  2. Authenticate with your Google Cloud deployment account.
  3. Copy and execute the generated script to append credentials to your `~/.gitcookies` file.
  4. Re-run `eab-deployer`.

- **Option 2 (Submit Directly via Cloud Build)**:
  If the infrastructure was already created by `eab-deployer` or Terraform, submit the application build directly into the Private Worker Pool:
  ```bash
  gcloud builds submit examples/default-example/6-appsource/default-example \
    --project=<PROJECT_ID> \
    --region=<REGION> \
    --config=examples/default-example/6-appsource/default-example/cloudbuild.yaml \
    --service-account=projects/<PROJECT_ID>/serviceAccounts/ci-<SERVICE_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
    --substitutions=_ATTESTOR_ID="projects/<PROJECT_ID>/attestors/gke-attestor",_BINARY_AUTH_IMAGE="<REGION>-docker.pkg.dev/<PROJECT_ID>/ar-eab-<SERVICE_NAME>-binauthz/binauthz-attestation:v1.0",_CLOUDDEPLOY_PIPELINE_NAME="<SERVICE_NAME>",_CONTAINER_REGISTRY="<REGION>-docker.pkg.dev/<PROJECT_ID>/<SERVICE_NAME>",_KMS_KEY_VERSION="projects/<PROJECT_ID>/locations/<REGION>/keyRings/kms-attestation-sign/cryptoKeys/attestation/cryptoKeyVersions/1",_PRIVATE_POOL="projects/<PROJECT_ID>/locations/<REGION>/workerPools/wp-eab-default-example",_SOURCE_STAGING_BUCKET="gs://bkt-release-source-development-<SERVICE_NAME>-<PROJECT_NUMBER>",COMMIT_SHA="main",SHORT_SHA="main"
  ```

### 7.2. Cloud Build Attestation Step Fails (`manifest unknown: Failed to fetch tag`)

**Error message:**
```text
Error response from daemon: manifest for <REGION>-docker.pkg.dev/<PROJECT_ID>/<SERVICE>/skaffold-example:<COMMIT_SHA>-dirty not found: manifest unknown
```

**Cause:**
When building via `skaffold` in non-git directories or custom contexts, `skaffold build` may default to tag `:latest` instead of `:$COMMIT_SHA-dirty`.

**Solution:**
Ensure `--tag=$COMMIT_SHA-dirty` is passed to the `skaffold build` command inside `cloudbuild.yaml`:
```bash
skaffold build --file-output=/workspace/artifacts.json --default-repo=$_CONTAINER_REGISTRY --cache-artifacts=false --tag=$COMMIT_SHA-dirty
```

