# Tutorial: Installing Kueue on GKE Private Cluster using Artifact Registry Remote Repository

This tutorial explains how to use the Artifact Registry remote repository to install Kueue on a Google Kubernetes Engine (GKE) private cluster that does not have access to Cloud NAT or the internet to download Docker images.

## Overview of Artifact Registry Remote Repositories

Artifact Registry remote repositories allow you to cache artifacts from upstream sources like Docker Hub, Maven Central, and others. They serve as proxies, storing cached versions of packages so that subsequent requests for the same package can be fulfilled locally without needing internet access.

## Secure Kueue Installation

The Terraform module `install_kueue`, located within the [3-fleetscope](../3-fleetscope/modules/install_kueue) directory, automates the setup of Kueue in a secure manner. This module performs the following key tasks:

1. **Creates an Artifact Registry Remote Repository**: It establishes a dedicated repository for proxying and caching Kueue images.

2. **Downloads and Updates Kueue Installation Manifests**: The module fetches the necessary installation manifests for Kueue from Github. It modifies the manifests to redirect image references from the original Kubernetes registry to the newly created Artifact Registry Repository.

3. **Applies Manifests**: The module utilizes the `terraform-google-gcloud` Terraform module to apply the updated manifests directly to your private GKE cluster by using ConnectGateway.

This eliminates the need to expose your GKE nodes to an external network during the Kueue installation process.

### Prerequisites

Before using the `install_kueue` module, ensure the following requirements are met:

- **Private GKE Cluster registered to a Fleet**: You must have an operational Private GKE Cluster in a Fleet. ConnectGateway requires the cluster to be in a Fleet.

- **Connect Gateway**: Connect Gateway must be enabled, it is used to securely connect to the Private Cluster, without having to expose a Control Plane External IP.

### Adding the Terraform Module to `3-fleetscope`

Fleetscope is a Good Stage to install Kueue, alongside other cluster installations, such as Config Sync and Service Mesh. To do so, you must add the module call inside `3-fleetscope/modules/env_baseline` base module.

1. Create a new file under `3-fleetscope/modules/env_baseline`, named `kueue.tf` and add the following code to it:

    ```terraform
    locals {
        fleet_membership_regex = "projects/([^/]+)/locations/([^/]+)/memberships/([^/]+)"
    }

    module "kueue" {
        for_each                 = toset(var.cluster_membership_ids)

        source                   = "../install_kueue"
        url                      = "https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml"
        project_id               = regex(local.fleet_membership_regex, each.value)[0]
        region                   = "us-central1"
        k8s_registry             = "registry.k8s.io"
        cluster_name             = regex(local.fleet_membership_regex, each.value)[2]
        cluster_region           = regex(local.fleet_membership_regex, each.value)[1]
        cluster_project          = regex(local.fleet_membership_regex, each.value)[0]
        cluster_service_accounts = var.cluster_service_accounts
    }
    ```

1. Apply changes by commiting to a named environment branch (`development`, `nonproduction`, `production`). After the build associated with the fleetscope repository finishes it's execution, kueue should be installed in the cluster.
