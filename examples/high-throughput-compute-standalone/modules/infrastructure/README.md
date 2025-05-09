# Deploying GKE, Artifact Registry & Parallelstore

This Terraform example demonstrates how to deploy a core infrastructure setup including a Google Kubernetes Engine (GKE) cluster, Artifact Registry, and Parallelstore instance. It provides a foundation for running risk and research workloads on Google Cloud.

## Features

* **GKE Cluster**: Deploy a Google Kubernetes Engine cluster with options for Standard or Autopilot mode
* **Artifact Registry**: Set up a repository for storing container images
* **Parallelstore**: Configure high-performance file storage for computational workloads
* **Network Setup**: Create a properly configured VPC network with necessary firewall rules
* **IAM Configuration**: Set up appropriate service accounts and permissions

## Prerequisites

* **Google Cloud Project:** A Google Cloud project with billing enabled
* **Terraform:** Terraform CLI (version 1.0+) installed and configured
* **Google Cloud SDK:** gcloud CLI configured with appropriate permissions
* **Required IAM Permissions:** User deploying must have sufficient permissions (typically Owner or Editor role)


## Deployment Instructions

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/GoogleCloudPlatform/risk-and-research-blueprints.git
   cd risk-and-research-blueprints/examples/infrastructure
   ```

2. **Configure Variables:**
   * Create a `terraform.tfvars` file with your configuration:
     ```hcl
     project_id = "your-project-id"
     regions    = ["us-central1"]  # Specify your preferred region

     # Optional configurations
     quota_contact_email = "your-email@example.com"  # For quota requests
     ```

3. **Deploy with Terraform:**

   * Authorize gcloud and set up application default credentials:
     ```bash
     gcloud auth login --activate --no-launch-browser --quiet --update-adc
     ```

   * Initialize, plan, and apply the Terraform configuration:
     ```bash
     terraform init
     terraform plan -var-file="terraform.tfvars" -out=tfplan
     terraform apply tfplan
     ```

4. **Access the GKE Cluster:**
   ```bash
   gcloud container clusters get-credentials gke-risk-research-[REGION]-0 --region [REGION]
   kubectl get nodes  # Verify connectivity
   ```

5. **Clean Up Resources:**
   When you're done with the environment, destroy the resources:
   ```bash
   terraform destroy -var-file="terraform.tfvars"
   ```

## What's Deployed

* GKE cluster configured for high-performance computing workloads
* Artifact Registry repository for container images
* Parallelstore file storage instance (if enabled)
* VPC network with appropriate subnets and firewall rules
* Service accounts with least-privilege permissions

## Advanced Configuration

For more advanced scenarios, you can modify the Terraform variables to:

* Deploy to multiple regions
* Enable/disable specific components
* Adjust performance settings for GKE and Parallelstore
* Configure custom networking options

See the `variables.tf` file for all available configuration options.
