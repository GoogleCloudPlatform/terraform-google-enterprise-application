# Contributing

We'd love to accept your patches and contributions to this project. There are
just a few guidelines to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your
contribution; this simply gives us permission to use and redistribute your
contributions as part of the project. Head over to
<https://cla.developers.google.com/> to see your current agreements on file or
to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code Reviews and Guidelines

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

We follow these guidelines:
- [Google Engineering Practices on Writing Good CL Descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html)
- [Google Engineering Practices on Code Review Speed](https://google.github.io/eng-practices/review/reviewer/speed.html)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [Google Cloud Terraform Best Practices](https://docs.cloud.google.com/docs/terraform/best-practices/general-style-structure)

> [!NOTE]
> If you are using AI coding assistants or LLM agents to contribute, refer to [AGENTS.md](./AGENTS.md) for architectural mental models, guardrails, and automated verification procedures.

## Development

The following dependencies must be installed on your development system:

- [Docker Engine][docker-engine]
- [Google Cloud SDK][google-cloud-sdk]
- [Go (1.26+)][golang] (for running integration tests locally)
- [make][make]
- [Terraform][terraform] (for formatting and running integration tests locally)

### Generating Documentation for Inputs and Outputs

The Inputs and Outputs tables in the READMEs of the root module,
submodules, and example modules are automatically generated based on
the `variables` and `outputs` of the respective modules using [terraform-docs][terraform-docs].
These tables must be refreshed if the module interfaces are changed.

#### Execution

Run `make generate_docs` (an alias for `make docker_generate_docs`; requires Docker) to generate new Inputs and Outputs tables.

### Linting and Formatting

All changes must pass `make docker_test_lint` (Terraform, TFLint, shell, Python, license header, whitespace, and generated-docs checks). CI also runs golangci-lint on the Go code in `test/integration`.

#### Execution

```bash
# Generate module documentation tables
make docker_generate_docs
```

You can also format files locally:

```bash
# Format Terraform files
terraform fmt -recursive

# Format Go files
gofmt -s -w helpers/ test/ modules/ examples/
```

Run the lint suite via Docker developer tools:

```bash
make docker_test_lint
```

### Integration Testing

Integration tests are written in Go using [Terratest][terratest] to verify the behavior of the modules and example scenarios. Additions, changes, and bug fixes should be accompanied by tests.

#### Test Environment Setup

Integration tests run against isolated Google Cloud projects. The provisioning harness is defined in the [test/setup/](./test/setup/) directory.

To use this setup, you need:

1. **Google Cloud Organization & Parent Folder**:
    - A Google Cloud Organization ID (`org_id`).
    - A parent Folder ID (`folder_id`) under which the setup creates a `seed` folder and the test projects.

1. **Billing Account**:
    - An active Google Cloud Billing Account linked to your organization.

1. **Deploying Identity IAM Roles**:
    The user or Service Account executing the deployment requires the following roles:
    - **Parent folder (`folder_id`)**:
        - `roles/resourcemanager.folderAdmin`
        - `roles/resourcemanager.projectCreator`
    - **Organization (`org_id`)**:
        - Permission to set the organization IAM policy (for example, `roles/resourcemanager.organizationAdmin`). The setup grants `organizationAdmin`, `compute.xpnAdmin`, `orgpolicy.policyAdmin`, and `accesscontextmanager.policyAdmin` to the CI service accounts.
    - **Billing account (`billing_account`)**:
        - `roles/billing.admin`
    - **Project Level (inside the sandbox project)**:
        - `roles/compute.admin` & `roles/compute.networkAdmin`
        - `roles/iam.serviceAccountAdmin` & `roles/iam.serviceAccountUser`
        - `roles/serviceusage.serviceUsageAdmin`

1. **Google Groups**:
    - Permission to create groups in your organization's Cloud Identity or Google Workspace domain. The setup creates one group per team for each tested example.

The project hosting the Service Account must have these APIs enabled:
- Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)
- Cloud Billing API (`cloudbilling.googleapis.com`)
- Service Usage API (`serviceusage.googleapis.com`)
- Identity and Access Management (IAM) API (`iam.googleapis.com`)

Export the Service Account key and set the required environment variables:

```bash
export SERVICE_ACCOUNT_JSON=$(< credentials.json)
export TF_VAR_org_id="your_org_id"
export TF_VAR_folder_id="your_folder_id"
export TF_VAR_billing_account="your_billing_account_id"
export TF_VAR_cloud_build_sa="service_account_email_of_your_credentials"
export TF_VAR_examples_tested='["default-example"]'
```

Prepare the test project using Docker:
```bash
make docker_test_prepare
```

Start an interactive shell in the testing container and run individual tests stage by stage, as CI does. Tests depend on outputs from `test/setup` and the harness tests (`TestLoggingBucket`, `TestGitLab`, `TestVPCSC`), so run them in the order used in `build/int.cloudbuild*.yaml`:

```bash
make docker_run
```

Inside the container:

```bash
cft test list
cft test run TestStandaloneSingleProjectDefaultExample --stage init --verbose
cft test run TestStandaloneSingleProjectDefaultExample --stage apply --verbose
cft test run TestStandaloneSingleProjectDefaultExample --stage verify --verbose
cft test run TestStandaloneSingleProjectDefaultExample --stage teardown --verbose
```

#### Running Tests Locally with Go

The tests use the CFT [blueprint test framework](https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit/tree/main/infra/blueprint-test), which is built on Terratest. To run a single stage with Go, set `RUN_STAGE`:

```bash
cd test/integration
RUN_STAGE=apply go test -v -run '^TestStandaloneSingleProjectDefaultExample$' ./default-example -timeout 60m
```

#### Cleaning Up Test Resources

After testing, clean up the test environment:

```bash
make docker_test_cleanup
```

[docker-engine]: https://www.docker.com/products/docker-engine
[golang]: https://go.dev/
[google-cloud-sdk]: https://cloud.google.com/sdk/install
[make]: https://en.wikipedia.org/wiki/Make_(software)
[terratest]: https://terratest.gruntwork.io/
[terraform-docs]: https://terraform-docs.io/
[terraform]: https://terraform.io/
