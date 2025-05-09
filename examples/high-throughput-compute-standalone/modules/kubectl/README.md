# Kubectl Module

This module provides version constraints for Terraform providers used in Kubernetes deployments via kubectl, ensuring consistent provider versions across the blueprint.

## Usage

```hcl
module "kubectl_config" {
  source = "github.com/GoogleCloudPlatform/risk-and-research-blueprints//terraform/modules/kubectl"
}
```

## Features

- Defines consistent version constraints for Google Cloud providers
- Ensures compatibility with Kubernetes resources
- Establishes a standard provider configuration for modules that interact with kubectl

## Providers

This module sets version constraints for the following providers:

| Provider | Version |
|----------|---------|
| google | ~> 6.29.0 |
| google-beta | ~> 6.29.0 |

## Notes

- This module primarily serves as a provider configuration reference
- Include this module in Terraform configurations that need to interact with Kubernetes via kubectl
- The module ensures consistent provider versions to avoid compatibility issues
- The provider_meta configuration ensures proper attribution of resources created by this module

## License

Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
