# Troubleshooting

## Problems

- [Common issues](#common-issues)
- [Billing quota exceeded](#billing-quota-exceeded)
- [Terraform Error acquiring the state lock](#terraform-error-acquiring-the-state-lock)

- - -

## Common issues

- [Project quota exceeded](#project-quota-exceeded)
- [Default branch setting](#default-branch-setting)
- [Billing quota exceeded](#billing-quota-exceeded)
- [Terraform Error acquiring the state lock](#terraform-error-acquiring-the-state-lock)
- [Terraform deploy fails due to GitLab repositories not found](#terraform-deploy-fails-due-to-gitlab-repositories-not-found)
- [Cannot assign requested address error in Cloud Shell](#cannot-assign-requested-address-error-in-cloud-shell)
- [Error: Gitlab pipelines access denied](#gitlab-pipelines-access-denied)
- [The user does not have permission to access Project or it may not exist](#the-user-does-not-have-permission-to-access-project-or-it-may-not-exist)
- [Quota 'CPUS_ALL_REGIONS' exceeded](#quota-cpus_all_regions-exceeded)
- [Shared VPC Attachment Destruction Failure due to Network Endpoint Group Link](#shared-vpc-attachment-destruction-failure-due-to-network-endpoint-group-link)
- [Network Destruction Failure due to Firewall still using it](#network-destruction-failure-due-to-firewall-still-using-it)
- [Cloud Source Repositories (CSR) Git Authentication Failure](#cloud-source-repositories-csr-git-authentication-failure)
- [Compute Engine External IP Restriction on Worker Pool NAT VM (`compute.vmExternalIpAccess`)](#compute-engine-external-ip-restriction-on-worker-pool-nat-vm-computevmexternalipaccess)
- [Binary Authorization Attestation Step Failure in CI Pipeline](#binary-authorization-attestation-step-failure-in-ci-pipeline)
- [Cloud Build Service Account Missing Permissions for Artifact Registry and Storage](#cloud-build-service-account-missing-permissions-for-artifact-registry-and-storage)
- [Interactive Prompt Blocking Automated IAM Binding due to Existing Conditional Policies](#interactive-prompt-blocking-automated-iam-binding-due-to-existing-conditional-policies)
- [Private GKE Autopilot Cluster Direct kubectl Connectivity Timeout](#private-gke-autopilot-cluster-direct-kubectl-connectivity-timeout)
- [Workflows Deletion Protection Error During Teardown (`google_workflows_workflow`)](#workflows-deletion-protection-error-during-teardown-google_workflows_workflow)
- [State Backend Lock / 404 Error During Stage 0 (0-bootstrap) Teardown](#state-backend-lock--404-error-during-stage-0-0-bootstrap-teardown)
- - -

### Project quota exceeded

**Error message:**

```text
Error code 8, message: The project cannot be created because you have exceeded your allotted project quota
```

**Cause:**

This message means you have reached your [project creation quota](https://support.google.com/cloud/answer/6330231).

**Solution:**

In this case, you can use the [Request Project Quota Increase](https://support.google.com/code/contact/project_quota_increase)
form to request a quota increase.

In the support form,
for the field **Email addresses that will be used to create projects**,
use the email address of `projects_step_terraform_service_account_email` that is created by the Terraform Example Foundation 0-bootstrap step.

**Notes:**

- If you see other quota errors, see the [Quota documentation](https://cloud.google.com/docs/quota).

### Default branch setting

**Error message:**

```text
error: src refspec master does not match any
```

**Cause:**

This could be due to init.defaultBranch being set to something other than
`main`.

**Solution:**

1. Determine your default branch:

   ```bash
   git config init.defaultBranch
   ```

   Outputs `main` if you are in the main branch.
1. If your default branch is not set to `main`, set it:

   ```bash
   git config --global init.defaultBranch main
   ```



**Error message:**

```text
Error 400: Unknown project id: 'prj-<business-unity>-<environment>-svpc-<random-suffix>', invalid
```

**Cause:**

When you try to run 4-projects step without requesting additional project quota for **project service account created in 0-bootstrap step** you may face the error above, even after the project quota issue is resolved, due to an inconsistency in terraform state.

**Solution:**

- Make sure you [have requested the additional project quota](#project-quota-exceeded) for the **project SA e-mail** before running the following steps.

You will need to mark some Terraform resources as **tainted** in order to trigger the recreation of the missing projects to fix the inconsistent in the terraform state.

1. In a terminal, navigate to the path where the error is being reported.

   For example, if the unknown project ID is `prj-bu1-p-svpc`, you should go to ./gcp-projects/business_unit_1/production (`business_unit_1` due to `bu1` and `production` due to `p`, see [naming conventions](https://cloud.google.com/architecture/security-foundations/using-example-terraform#naming_conventions) for more information on the projects naming guideline).

   ```bash
   cd ./gcp-projects/<business_unit>/<environment>
   ```

1. Run the `terraform init` command so you can pull the remote state.

   ```bash
   terraform init
   ```

1. Run the `terraform state list` command, filtering by `random_project_id_suffix`.
This command will give you all the expected projects that should be created for this BU and environment that uses a random suffix.

   ```bash
   terraform state list | grep random_project_id_suffix
   ```

1. Identify the folder which is the parent of the projects of the environment.
If the Terraform Example Foundation is deployed directly under the organization use `--organization`, if the Terraform Example Foundation is deployed under a folder use `--folder`. The "ORGANIZATION_ID" and "PARENT_FOLDER" are the input values provided for the 0-bootstrap step.

   ```bash
   gcloud resource-manager folders list [ --organization=ORGANIZATION_ID ][ --folder=PARENT_FOLDER ]
   ```

1. The result of the `gcloud` command will look like the following output.
Using the `production` environment for this example, the folder ID for the environment would be `333333333333`.

   ```
   DISPLAY_NAME         PARENT_NAME                     ID
   fldr-bootstrap       folders/PARENT_FOLDER  111111111111
   fldr-common          folders/PARENT_FOLDER  222222222222
   fldr-production      folders/PARENT_FOLDER  333333333333
   fldr-nonproduction  folders/PARENT_FOLDER  444444444444
   fldr-development     folders/PARENT_FOLDER  555555555555
   ```

1. Run the `gcloud projects list` command to.
Replace `id_of_the_environment_folder` with the proper ID of the folder retrieved in the previous step.
This command will give you all the projects that were actually created.

   ```bash
   gcloud projects list --filter="parent=<id_of_the_environment_folder>"
   ```

1. For each resource listed in the `terraform state` step for a project that is **not** returned by the `gcloud projects list` step, we should mark that resource as tainted to force it to be recreated in order to fix the inconsistency in the terraform state.

   ```bash
   terraform taint <resource>[index]
   ```

   For example, in the following command we are marking as tainted the env secrets project. You may need to run the `terraform taint` command multiple times, depending on how many missing projects you have.

   ```bash
   terraform taint module.env.module.env_secrets_project.module.project.module.project-factory.random_string.random_project_id_suffix[0]
   ```

1. After running the `terraform taint` command for all the non-matching items, go to Cloud Build and trigger a retry action for the failed job.
This should complete successfully, if you encounter another similar error for another BU/environment that will require you to follow this guide again but instead changing paths according to the BU/environment reported in the error log.

**Notes:**

   - Make sure you run the taint command just for the resources that contain the [number] at the end of the line returned by terraform state list step. You don't need to run for the groups (the resources that don't have the [] at the end).


### Billing quota exceeded

**Error message:**

```text
Error: Error setting billing account "XXXXXX-XXXXXX-XXXXXX" for project "projects/some-project": googleapi: Error 400: Precondition check failed., failedPrecondition
```

**Cause:**

Most likely this is related to a billing quota issue.

**Solution:**

try

```bash
gcloud alpha billing projects link projects/some-project --billing-account XXXXXX-XXXXXX-XXXXXX
```

If output states `Cloud billing quota exceeded`, you can use the [Request Billing Quota Increase](https://support.google.com/code/contact/billing_quota_increase) form to request a billing quota increase.

### Terraform Error acquiring the state lock

**Error message:**

```text
Error: Error acquiring the state lock
```

**Cause:**

This message means that you are trying to apply a Terraform configuration with a remote backend that is in a [locked state](https://www.terraform.io/language/state/locking).

If the Terraform process was unable to finish due to an unexpected event, i.e build timeout or terraform process killed. It will keep the Terraform State **locked**.

**Solution:**

The following commands are an example of how to unlock the **development environment** from step 2-environments that is one part of the Foundation Example.
It can also be applied in the same way to the other parts.

1. Clone the repository where you got the Terraform State lock. The following example assumes **development environment** from step 2-environments:

   ```bash
   gcloud source repos clone gcp-environments --project=YOUR_CLOUD_BUILD_PROJECT_ID
   ```

1. Navigate into the repo and change to the development branch:

   ```bash
   cd gcp-environments
   git checkout development
   ```

1. If your project does not have a remote backend you can jump skip the next 2 commands and jump to `terraform init` command.
1. If your project has a remote backend you will have to update `backend.tf` with the remote state backend bucket.
You can get this information from step `0-bootstrap` by running the following command:

   ```bash
   terraform output gcs_bucket_tfstate
   ```

1. Update `backend.tf` with the remote state backend bucket you got on previously inside `<YOUR-REMOTE-STATE-BACKEND-BUCKET>`:

   ```bash
   for i in `find . -name 'backend.tf'`; do sed -i'' -e 's/UPDATE_ME/<YOUR-REMOTE-STATE-BACKEND-BUCKET>/' $i; done
   ```

1. Navigate into `envs/development` where your terraform config files are in and run terraform init:

   ```bash
   cd envs/development
   terraform init
   ```

1. At this point, you will be able to get Terraform State lock information and unlock your state.
1. After running terraform apply you should get an error message like the following:

   ```text
   terraform apply
   Acquiring state lock. This may take a few moments...
   ╷
   │ Error: Error acquiring the state lock
   │
   │ Error message: writing "gs://<YOUR-REMOTE-STATE-BACKEND-BUCKET>/<PATH-TO-TERRAFORM-STATE>/<tf state file name>.tflock" failed: googleapi: Error 412: At least one
   │ of the pre-conditions you specified did not hold., conditionNotMet
   │ Lock Info:
   │   ID:        1664568683005669
   │   Path:      gs://<YOUR-REMOTE-STATE-BACKEND-BUCKET>/<PATH-TO-TERRAFORM-STATE>/<tf state file name>.tflock
   │   Operation: OperationTypeApply
   │   Who:       user@domain
   │   Version:   1.0.0
   │   Created:   2022-09-30 20:11:22.90644727 +0000 UTC
   │   Info:
   │
   │
   │ Terraform acquires a state lock to protect the state from being written
   │ by multiple users at the same time. Please resolve the issue above and try
   │ again. For most commands, you can disable locking with the "-lock=false"
   │ flag, but this is not recommended.
   ```

1. With the lock `ID` you will be able to remove the Terraform State lock using `terraform force-unlock` command. It is a **strong recommendation** to review the official documentation regarding [terraform force-unlock](https://www.terraform.io/language/state/locking#force-unlock) command before executing it.
1. After unlocking the Terraform State you will be able to execute a `terraform plan` for review of the state. The following links can help you to recover the Terraform State for your configuration and move on:
    1. [Manipulating Terraform State](https://developer.hashicorp.com/terraform/cli/state)
    1. [Moving Resources](https://developer.hashicorp.com/terraform/cli/state/move)
    1. [Importing Infrastructure](https://developer.hashicorp.com/terraform/cli/import)

**Terraform State lock possible causes:**

- If you realize that the Terraform State lock was due to a build timeout increase the build timeout on [build configuration](https://github.com/terraform-google-modules/terraform-example-foundation/blob/main/build/cloudbuild-tf-apply.yaml#L15).

### Terraform deploy fails due to GitLab repositories not found

**Error message:**

```text
Error: POST https://gitlab.com/api/v4/projects/<GITLAB-ACCOUNT>/<GITLAB-REPOSITORY>/variables: 404 {message: 404 Project Not Found}

```

**Cause:**

This message means that you are using a wrong Access Token or you have Access Token created in both Gitlab Account/Group and GitLab Repository.

Only Personal Access Token under GitLab Account/Group should exist.

**Solution:**

Remove any Access Token from the GitLab repositories used by Google Secure Foundation Blueprint.

### Gitlab pipelines access denied

**Error message:**

From the logs of your Pipeline job:

```text
Error response from daemon: pull access denied for registry.gitlab.com/<YOUR-GITLAB-ACCOUNT>/<YOUR-GITLAB-CICD-REPO>/terraform-gcloud, repository does not exist or may require 'docker login': denied: requested access to the resource is denied
```

**Cause:**

The cause of this message is that the CI/CD repository has "Limit access to this project" enabled in the Token Access settings.

**Solution:**

Add all the projects/repositories to be used in the Terraform Example Foundation to the allow list available in
`CI/CD Repo -> Settings -> CI/CD -> Token Access -> Allow CI job tokens from the following projects to access this project`.

### The user does not have permission to access Project or it may not exist

**Error message:**

```text
Error when reading or editing GCS service account not found: googleapi: Error 400: Unknown project id: <PROJECT-ID>, invalid.
The user does not have permission to access Project <PROJECT-ID> or it may not exist.
```

**Cause:**

Terraform is trying to fetch or manipulate resources associated with the given project **PROJECT-ID** but the project was not created in the first execution.

What was created in the first execution was the project id that will be used to create the project. The project id is a composition of a fixed prefix and a random suffix.

Possible causes of the project creation failure in the first execution are:

- The user does not have Billing Account User role in the billing account
- The user does not have Project Creator role in the Google Cloud organization
- The user has reached the project creation quota
- Terraform apply failed midway due to a timeout or an interruption, leaving the project ID generated in the state but not creating the project itself

**Solution:**

If the cause is the project creation quota issue. Follow instruction in the Terraform Example Foundation [troubleshooting](https://github.com/terraform-google-modules/terraform-example-foundation/blob/main/docs/TROUBLESHOOTING.md#billing-quota-exceeded)

After doing this fixes you need to force the recreation of the random suffix used in the project ID.
To force the creation run

```bash
terraform taint <RESOURCE-ID>
```

For example

```
terraform taint module.seed_bootstrap.module.seed_project.module.project-factory.random_id.random_project_id_suffix
```

And try again to do the deployment.

### Quota 'CPUS_ALL_REGIONS' exceeded

**Error message:**

```text
 Insufficient quota to satisfy the request: Not all instances running in IGM after 35.330554867s. Expected 1, running 0, transitioning 1. Current errors: [GCE_QUOTA_EXCEEDED]: Instance 'gke-cluster-us-central1-n-node-pool-1-c52d2d09-sqss' creation failed: Quota 'CPUS_ALL_REGIONS' exceeded. Limit: 32.0 globally.
```

**Cause:**

Your project exausted the Compute CPUS_ALL_REGIONS quota.

**Solution:**

Go to you [project quota page](https://console.cloud.google.com/iam-admin/quotas).Search for CPUS_ALL_REGIONS. Click on the three dots and then click in Edit. The quota can take some time to be granted.

### Insufficient free IP addresses

**Error message:**
```text
Instance 'gk3-cluster-us-central1--nap-16v5qeju-0beefc19-2nf4'
creation failed: IP space of 'projects/wiz-eab-net-dev-aef1/regions/us-central1/subnetworks/dev-net-02-dev-net-02-serv-481f020495955c17'
is exhausted. Insufficient free IP addresses in the IP range '192.168.67.0/24'.
Consider expanding the current IP range or selecting an alternative IP range.
If this is a secondary range, consider adding an additional secondary range.'
```

**Cause:**

All IPs in your range are already taken.

**Solution:**

You can add a new secondary range in your subnetwork. You can check more information on the oficial [documentation](https://cloud.google.com/vpc/docs/configure-alias-ip-ranges#adding_secondary_cidr_ranges_to_an_existing_subnet).

```bash
gcloud compute networks subnets update SUBNET_NAME \
    --region REGION \
    --add-secondary-ranges RANGE_NAME_1=RANGE_CIDR_1,RANGE_NAME_2=RANGE_CIDR_2,...
```

### Shared VPC Attachment Destruction Failure due to Network Endpoint Group Link

**Error message:**

```text
# module.env.module.eab_cluster_project[0].module.project-factory.google_compute_shared_vpc_service_project.shared_vpc_attachment[0]: Destroying... [id=VPC_DEVELOPMENT_PROJECT_ID/GKE_PROJECT_ID]
# module.env.module.eab_cluster_project[0].module.project-factory.google_compute_shared_vpc_service_project.shared_vpc_attachment[0]: Still destroying... [id=VPC_DEVELOPMENT_PROJECT_ID/GKE_PROJECT_ID, 00m10s elapsed]
#
# Error: Error disabling Shared VPC Resource "GKE_PROJECT_ID": Error waiting for Disabling Shared VPC Resource: The resource 'projects/GKE_PROJECT_ID/zones/ZONE/networkEndpointGroups/k8s1-CLUSTER_ID-kube-system-default-http-backend-80-RANDOM_HASH' is still linked to shared VPC host 'projects/VPC_DEVELOPMENT_PROJECT_ID'.
```

**Cause:**

This error occurs during the destroy process (either via `$HOME/go/bin/eab-deployer -destroy` or `terraform destroy`) because there is a problem when a Autopilot GKE cluster uses a Shared VPC network. The project where the Autopilot GKE cluster is deployed retains a network endpoint group (NEG) attached to the shared VPC network, even after the deletion on the Autopilot GKE cluster. This persistent link prevents the successful destruction of the Shared VPC attachment.

**Solution:**

To resolve this, you need to manually remove the Shared VPC attachment resource from the Terraform state. This will allow the destroy process to proceed without being blocked by the linked NEG.

1.  **Navigate to the deployment path for the failing environment.** The environment name (e.g., `development`) can be identified from the resource names in the error message. Replace `<ENVIRONMENT>` with your environment name in the command below.

    ```bash
    cd eab-multitenant/envs/<ENVIRONMENT>
    ```

2.  **Remove the Shared VPC attachment resource from the Terraform state:**

    ```bash
    terraform state rm module.env.module.eab_cluster_project[0].module.project-factory.google_compute_shared_vpc_service_project.shared_vpc_attachment[0]
    ```

    The expected output should be similar to:

    ```bash
    Acquiring state lock. This may take a few moments...
    Removed module.env.module.eab_cluster_project[0].module.project-factory.google_compute_shared_vpc_service_project.shared_vpc_attachment[0]
    Successfully removed 1 resource instance(s).
    Releasing state lock. This may take a few moments...
    ```

3.  **Go back to the root of your deployment path and re-run the destroy helper:**

    ```bash
    cd ../../../
    $HOME/go/bin/eab-deployer -tfvars_file <PATH TO 'global.tfvars' FILE> -destroy
    ```

### Network Destruction Failure due to Firewall still using it

**Error message:**

```text
module.cluster_network.module.cluster_vpc.module.vpc.google_compute_network.network: Destroying... [id=projects/PROJECT_ID/global/networks/NETWORK_CLUSTER_NAME]
module.cluster_network.module.cluster_vpc.module.vpc.google_compute_network.network: Still destroying... [id=projects/PROJECT_ID/global/networks/NETWORK_CLUSTER_NAME, 00m10s elapsed]
╷
│ Error: Error waiting for Deleting Network: The network resource 'projects/PROJECT_ID/global/networks/NETWORK_CLUSTER_NAME' is already being used by 'projects/PROJECT_ID/global/firewalls/gke-cluster-ZONE-development-RANDOM_HASH-mcsd'
╷
│ Error: Error waiting for Deleting Network: The network resource 'projects/PROJECT_ID/global/networks/vpc-eab-cluster' is already being used by 'projects/PROJECT_ID/global/firewalls/gke-csm-thc-RANDOM_HASH'
```

**Cause:**

This error occurs during the destroy process (either via `$HOME/go/bin/eab-deployer -destroy` or `terraform destroy`) because there is a problem in the cleanup of a Autopilot GKE cluster. Some firewall rules created by GKE service are not correctly cleanup, even after the deletion on the Autopilot GKE cluster. This persistent link prevents the successful destruction of the Shared VPC attachment.

**Solution:**

To resolve this, you need to manually remove the firewall rules and then proceed with destroy. You can do it either in the Console or running a gcloud command.

1. List all firewall rules that contains `csm` and `-mcsd` in the name:

   ```bash
      gcloud compute firewall-rules list  --project <NETWORK_PROJECT> --filter=\"csm\"
   ```

1. Delete the listed firewall-rules:

   ```bash
      gcloud compute firewall-rules delete <FIREWALL-RULE-NAME>  --project <NETWORK_PROJECT>
   ```

### Cloud Source Repositories (CSR) Git Authentication Failure

**Error message:**

```text
fatal: unable to access 'https://source.developers.google.com/p/<PROJECT_ID>/r/<REPO_NAME>/': The requested URL returned error: 400 Invalid authentication credentials.
Please generate a new identifier: https://source.developers.google.com/new-password
```

**Cause:**

When using `repo_type = "CSR"` in `global.tfvars`, `eab-deployer` attempts to clone the Cloud Source Repository using the local Git client. Google Cloud requires explicit Git credentials or cookies when cloning from local environments without an active CSR git credential helper.

**Solution:**

Choose one of the following approaches:

1. **Configure Git Cookie Credentials**:
   - Open [https://source.developers.google.com/new-password](https://source.developers.google.com/new-password) in your browser.
   - Authenticate with your Google Cloud deployment account.
   - Follow the instructions to run the generated shell command, which configures your `~/.gitcookies` file.
   - Re-run `$HOME/go/bin/eab-deployer -tfvars_file global.tfvars`.

2. **Trigger Build Directly via Cloud Build**:
   If the infrastructure was already provisioned, submit the application build directly to Cloud Build using the Private Worker Pool:
   ```bash
   gcloud builds submit examples/default-example/6-appsource/default-example \
     --project=<PROJECT_ID> \
     --region=<REGION> \
     --config=examples/default-example/6-appsource/default-example/cloudbuild.yaml \
     --service-account=projects/<PROJECT_ID>/serviceAccounts/ci-<SERVICE_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
     --substitutions=_ATTESTOR_ID="projects/<PROJECT_ID>/attestors/gke-attestor",_BINARY_AUTH_IMAGE="<REGION>-docker.pkg.dev/<PROJECT_ID>/ar-eab-<SERVICE_NAME>-binauthz/binauthz-attestation:v1.0",_CLOUDDEPLOY_PIPELINE_NAME="<SERVICE_NAME>",_CONTAINER_REGISTRY="<REGION>-docker.pkg.dev/<PROJECT_ID>/<SERVICE_NAME>",_KMS_KEY_VERSION="projects/<PROJECT_ID>/locations/<REGION>/keyRings/kms-attestation-sign/cryptoKeys/attestation/cryptoKeyVersions/1",_PRIVATE_POOL="projects/<PROJECT_ID>/locations/<REGION>/workerPools/wp-eab-default-example",_SOURCE_STAGING_BUCKET="gs://bkt-release-source-development-<SERVICE_NAME>-<PROJECT_NUMBER>",COMMIT_SHA="main",SHORT_SHA="main"
   ```

3. **Use 2nd-gen Repositories (GitHub / GitLab)**:
   In `global.tfvars`, configure `cloudbuildv2_repository_config` to use GitHub (`repo_type = "GITHUBv2"`) or GitLab (`repo_type = "GITLABv2"`).

### Compute Engine External IP Restriction on Worker Pool NAT VM (`compute.vmExternalIpAccess`)

**Error message:**

```text
Error: Error creating Instance: googleapi: Error 412: Constraint constraints/compute.vmExternalIpAccess violated for projects/PROJECT_ID/zones/ZONE/instances/eab-vpc-workerpool-cloud-build-nat-vm.
```

**Cause:**

Enterprise Foundation v7 enforces the organizational policy `constraints/compute.vmExternalIpAccess` by default. This policy prohibits Compute Engine instances from obtaining public external IP addresses. When setting `create_nat = true` in EAB standalone or worker pool configurations, a Compute Engine NAT gateway VM is provisioned to provide egress internet access for container builds (fetching PyPI packages, ADK dependencies, etc.), which requires an external IP.

**Solution:**

Configure an organization policy override allowing external IP allocation specifically for the NAT VM across all candidate zones:

```bash
PROJECT_ID="<YOUR_SERVICE_PROJECT_ID>"

gcloud org-policies allow compute.vmExternalIpAccess \
  projects/${PROJECT_ID}/zones/us-central1-a/instances/eab-vpc-workerpool-cloud-build-nat-vm \
  projects/${PROJECT_ID}/zones/us-central1-b/instances/eab-vpc-workerpool-cloud-build-nat-vm \
  projects/${PROJECT_ID}/zones/us-central1-c/instances/eab-vpc-workerpool-cloud-build-nat-vm \
  projects/${PROJECT_ID}/zones/us-central1-f/instances/eab-vpc-workerpool-cloud-build-nat-vm \
  --project=${PROJECT_ID}
```

---

### Binary Authorization Attestation Step Failure in CI Pipeline

**Error message:**

```text
Step #3 - "create-attestation": Error: could not find attestor or KMS key
Step #3 - "create-attestation": Finished step #3 - "create-attestation" with status: ERROR
ERROR: build step 3 "create-attestation" failed: step exited with non-zero status: 1
```

**Cause:**

In standalone single-project mode or environments where `attestation_kms_key = null`, no Binary Authorization attestor is provisioned. The standard CI pipeline step attempts to sign the container image using the attestor and fails if it does not exist.

**Solution:**

Add `allowFailure: true` to the `create-attestation` step in `cloudbuild.yaml`:

```yaml
- id: 'create-attestation'
  name: '$_BINARY_AUTH_IMAGE'
  allowFailure: true
  args:
    - '--artifact-url'
    - "$$(cat /workspace/image_url.txt)"
    - '--attestor'
    - '$_ATTESTOR_ID'
    - '--keyversion'
    - '$_KMS_KEY_VERSION'
```

---

### Cloud Build Service Account Missing Permissions for Artifact Registry and Storage

**Error message:**

```text
denied: Permission "artifactregistry.repositories.uploadArtifacts" denied on resource "projects/PROJECT_ID/locations/REGION/repositories/REPOSITORY"
```
or
```text
AccessDeniedException: 403 Caller does not have storage.objects.create access to bucket ...
```

**Cause:**

When running builds via Cloud Build private worker pools in existing Foundation service projects, the dedicated team CI service account (`ci-<service-name>@PROJECT_ID.iam.gserviceaccount.com`) or the Cloud Build Service Agent requires explicit IAM roles to push artifacts, write build logs, and invoke Cloud Deploy.

**Solution:**

Grant the necessary roles to the CI Service Account and Cloud Build Service Agent:

```bash
PROJECT_ID="<YOUR_PROJECT_ID>"
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

# Grant Artifact Registry and Logging permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:ci-capital-agent@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:ci-capital-agent@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter" \
  --condition=None

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:ci-capital-agent@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin" \
  --condition=None

# Allow CI Service Account to impersonate the Deploy Service Account
gcloud iam service-accounts add-iam-policy-binding \
  deploy-capital-agent@${PROJECT_ID}.iam.gserviceaccount.com \
  --member="serviceAccount:ci-capital-agent@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --project=${PROJECT_ID}

# Cloud Build Service Agent permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com" \
  --role="roles/storage.admin" \
  --condition=None
```

---

### Interactive Prompt Blocking Automated IAM Binding due to Existing Conditional Policies

**Error message:**

```text
This policy contains conditions.
[1] Condition: ...
[2] None
Which condition would you like to edit?
```

**Cause:**

Foundation v7 stages (such as `1-org` or `2-environments`) configure conditional IAM policies on projects (e.g. for log view access or monitoring). When running `gcloud projects add-iam-policy-binding` without specifying a condition flag, `gcloud` halts execution with an interactive menu.

**Solution:**

Always append `--condition=None` to `gcloud projects add-iam-policy-binding` commands when executing in non-interactive CI/CD runners or automated scripts:

```bash
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:..." \
  --role="roles/..." \
  --condition=None
```

---

### Private GKE Autopilot Cluster Direct kubectl Connectivity Timeout

**Error message:**

```text
Unable to connect to the server: dial tcp 172.16.0.2:443: i/o timeout
```

**Cause:**

In compliance with enterprise security baselines, GKE Autopilot clusters provisioned by EAB have private control plane endpoints enabled and public endpoints disabled. Standard `kubectl` commands executed from outside the VPC cannot route directly to private control plane RFC 1918 addresses.

**Solution:**

Connect securely through Google Cloud Connect Gateway without needing a bastion host or VPN:

```bash
# Obtain Connect Gateway credentials
gcloud container fleet memberships get-credentials ag-cluster-us-central1-development \
  --project=<PROJECT_ID>

# Interact with the cluster via kubectl
kubectl get pods -A
```

---

### Workflows Deletion Protection Error During Teardown (`google_workflows_workflow`)

**Error message:**

```text
Error: cannot destroy workflow without setting deletion_protection=false and running `terraform apply`
```

**Cause:**

In Google Cloud Provider v6+, the `google_workflows_workflow` resource has `deletion_protection = true` enabled by default. During teardown of Foundation `0-bootstrap`, Terraform rejects destroying the workflow directly.

**Solution:**

Remove the workflow resource from the Terraform state and allow the project deletion to clean up the resource automatically:

```bash
terraform state rm module.tf_cloud_builder.google_workflows_workflow.builder
```

---

### State Backend Lock / 404 Error During Stage 0 (0-bootstrap) Teardown

**Error message:**

```text
Error: Failed to upload state to gs://bkt-prj-b-seed-tfstate-xxxx/terraform/bootstrap/state/default.tfstate: googleapi: Error 404: The specified bucket does not exist., notFound
Error: Failed to persist state to backend
Error: Error releasing the state lock
```

**Cause:**

During `terraform destroy` in Foundation `0-bootstrap`, Terraform deletes the remote state bucket (`bkt-prj-b-seed-tfstate-...`). Because the bucket itself is destroyed before the final state write, Terraform cannot persist the updated state to GCS and writes `errored.tfstate` locally.

**Solution:**

Migrate the state back to a local backend to finish destroying remaining seed resources:

1. Temporarily move or rename `backend.tf`:
   ```bash
   mv backend.tf backend.tf.bak
   ```
2. Copy `errored.tfstate` as the local state:
   ```bash
   cp errored.tfstate terraform.tfstate
   ```
3. Remove the remote backend cache file:
   ```bash
   rm .terraform/terraform.tfstate
   ```
4. Re-initialize Terraform locally:
   ```bash
   terraform init
   ```
5. Complete the destruction cleanly:
   ```bash
   terraform destroy -auto-approve
   ```


