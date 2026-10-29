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

We follow standard Google Engineering Practices:
- [Google Engineering Practices on Writing Good CL Descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html)
- [Google Engineering Practices on Code Review Speed](https://google.github.io/eng-practices/review/reviewer/speed.html)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [Google Cloud Terraform Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)

> [!NOTE]
> If you are using AI coding assistants or LLM agents to contribute, refer to [AGENTS.md](./AGENTS.md) for architectural mental models, guardrails, and automated verification procedures.

## Development

The following dependencies must be installed on your development system:

- [Docker Engine][docker-engine]
- [Google Cloud SDK][google-cloud-sdk]
- [Go (1.21+)][golang] (for running integration tests locally)
- [make][make]

### Generating Documentation for Inputs and Outputs

The Inputs and Outputs tables in the READMEs of the root module,
submodules, and example modules are automatically generated based on
the `variables` and `outputs` of the respective modules using `terraform-docs`.

#### Execution

Run `make generate_docs` (or `make docker_generate_docs`) to generate new Inputs and Outputs tables.

### Linting and Formatting

All Terraform, Shell, Go, and YAML files must be formatted and linted before submission.

#### Execution

Run the lint suite via Docker developer tools:
```bash
make docker_test_lint
```

You can also format files locally:
```bash
# Format Terraform files
terraform fmt -recursive

# Format Go files
gofmt -s -w helpers/ test/
```

### Integration Testing

Integration tests are written in Go using [Terratest][terratest] to verify the behaviour of the modules and example scenarios. Additions, changes, and bug fixes should be accompanied by tests.

#### Test Environment Setup

Integration tests run against isolated Google Cloud projects. The provisioning harness is defined in the [test/setup/](./test/setup/) directory.

To use this setup, you need a Service Account with the following roles on a Folder or Organization:
- Project Creator (`roles/resourcemanager.projectCreator`)
- Billing Account User (`roles/billing.user`)

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
```

Prepare the test project using Docker:
```bash
make docker_test_prepare
```

#### Running Tests via Docker

Run the entire integration test suite non-interactively:
```bash
make docker_test_integration
```

Or start an interactive shell in the testing container:
```bash
make docker_run
```

#### Running Tests Locally with Go

You can run individual Terratest suites directly:

```bash
cd test/integration
go test -v -run TestDefaultExample ./default-example -timeout 60m
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
