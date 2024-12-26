# Upgrade Guide: Version 0.2.0 to 0.3.0

This document is designed to help you navigate the changes and improvements included in the v0.3.0 release. Upgrading ensures that you benefit from enhanced features, security updates, and bug fixes.

Key Steps for a Successful Upgrade
- Configure the newly introduced `cloudbuildv2_repository_config` variable for existing cloud source repositories.

Review Release Notes: Familiarize yourself with the new features, improvements, and any breaking changes introduced in version 0.3.0.

## Sample Application Change

In version v0.2.0, the default sample application used on the repository was `cymbal-bank`. It now has been relocated to the `examples/` directory under at the repository root. The new default example is a lightweight application named `hello-world`, the new example features cross-platform builds for ARM64 and x86 architectures and the use of ARM nodes in GKE.

## CSR Users

The key breaking change introduced in v0.3.0 is that now the user making use of CSR repositories will need to define the `cloudbuildv2_repository_config` variable when calling the `cicd-pipeline` module defined in 5-appinfra, here is an example for the configuration of this varialbe when using a cloud source repository named "eab-default-example-hello-world":

```terraform
cloudbuildv2_repository_config = {
  repo_type = "CSR"
  repositories = {
    "eab-default-example-hello-world" = {
      repository_name = "eab-default-example-hello-world"
      repository_url  = ""
    }
  }
}
```




