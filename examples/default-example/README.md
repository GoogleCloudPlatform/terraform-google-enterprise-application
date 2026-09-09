# Default Example (Hello World)

This is the default reference example of the Enterprise Application Blueprint. It demonstrates how to establish an internal developer platform to deploy a simple, containerized **Hello World** Go application across different environment stages using secure CI/CD pipelines.

The example is split into the following subdirectories:
- **`4-appfactory/`**: Contains the application registration configuration (`terraform.tfvars`) used by the App Factory pipeline to set up the dedicated application projects and source code repositories.
- **`5-appinfra/`**: Contains the application infrastructure stage configuring the secure, dedicated application CI/CD pipelines, Artifact Registry, and Cloud Deploy targets.
- **`6-appsource/`**: Contains the Go source code of the Hello World application, along with its `skaffold.yaml` and Kubernetes deployment manifests.
- **`standalone-single-project/`**: A simplified sandbox version designed to deploy the Hello World example in a single-project standalone setup.

## Usage

For complete end-to-end instructions on how to use and deploy this reference example, please refer to the primary [root README.md](../../README.md) and the step-by-step guides inside each module and subdirectory.
