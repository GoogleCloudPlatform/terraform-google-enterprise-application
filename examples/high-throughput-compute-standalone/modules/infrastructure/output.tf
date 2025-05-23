# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#-----------------------------------------------------
# GKE Cluster Outputs
#-----------------------------------------------------

output "gke_clusters" {
  description = "List of GKE cluster details including names, regions, and endpoints for connecting via kubectl"
  value = [
    for k, cluster in module.gke_standard : {
      cluster_name   = cluster.cluster_name
      region         = cluster.region
      endpoint       = cluster.endpoint
      node_pools     = cluster.node_pools
      cluster_config = cluster.cluster_config
      features = {
        enabled_csi_drivers = {
          parallelstore = var.enable_csi_parallelstore
          filestore     = var.enable_csi_filestore
          gcs_fuse      = var.enable_csi_gcs_fuse
        }
        workload_identity_enabled = var.enable_workload_identity
        secure_boot_enabled       = var.enable_secure_boot
        shielded_nodes_enabled    = var.enable_shielded_nodes
      }
    }
  ]
}

output "gke_credentials_command" {
  description = "gcloud commands to fetch credentials for each GKE cluster"
  value = length(module.gke_standard) > 0 ? {
    for k, cluster in module.gke_standard : cluster.cluster_name => "gcloud container clusters get-credentials ${cluster.cluster_name} --region ${cluster.region} --project ${var.project_id}"
  } : {}
}

output "gke_cluster_count" {
  description = "Total number of GKE clusters deployed across all regions"
  value       = length(module.gke_standard)
}

output "gke_clusters_by_region" {
  description = "Map of regions to GKE clusters deployed in each"
  value = {
    for region in var.regions : region => [
      for k, cluster in module.gke_standard : cluster.cluster_name if split("-", k)[0] == region
    ]
  }
}

#-----------------------------------------------------
# Artifact Registry Outputs
#-----------------------------------------------------

output "artifact_registry" {
  description = "Details of the Artifact Registry repository for storing container images"
  value = {
    name              = module.artifact_registry.artifact_registry.name
    url               = module.artifact_registry.artifact_registry_url
    artifact_registry = module.artifact_registry.artifact_registry
    id                = module.artifact_registry.artifact_registry_id
    location          = module.artifact_registry.artifact_registry_region
  }
}

output "artifact_registry_docker_command" {
  description = "Command to configure Docker to push to this Artifact Registry repository"
  value       = "gcloud auth configure-docker ${module.artifact_registry.artifact_registry_region}-docker.pkg.dev"
}

output "artifact_registry_push_command" {
  description = "Example command to tag and push a Docker image to this Artifact Registry repository"
  value       = "docker tag IMAGE:TAG ${module.artifact_registry.artifact_registry_url}/IMAGE:TAG && docker push ${module.artifact_registry.artifact_registry_url}/IMAGE:TAG"
}

#-----------------------------------------------------
# Network Outputs
#-----------------------------------------------------

output "vpc" {
  description = "Details of the VPC network resources created for the deployment"
  value = {
    id                  = google_compute_network.research-vpc.id
    name                = google_compute_network.research-vpc.name
    mtu                 = google_compute_network.research-vpc.mtu
    self_link           = google_compute_network.research-vpc.self_link
    gateway_ipv4        = google_compute_network.research-vpc.gateway_ipv4
    routing_mode        = google_compute_network.research-vpc.routing_mode
    auto_create_subnets = google_compute_network.research-vpc.auto_create_subnetworks
  }
}

output "subnets" {
  description = "Map of networking resources per region including subnets and IP ranges for Kubernetes"
  value = {
    for region, network in module.networking : region => {
      subnet_id          = network.subnet_id
      subnet_name        = network.subnet_name
      service_range_name = network.service_range_name
      pod_range_name     = network.pod_range_name
      nat_ip             = network.nat_ip
      router_id          = network.router_id
    }
  }
}

output "peering_config" {
  description = "VPC Network Peering configuration for service networking (used by high-performance storage)"
  value = {
    name                 = "servicenetworking-googleapis-com"
    network              = google_compute_network.research-vpc.name
    peering_range        = google_compute_global_address.storage_range.name
    peering_range_ip     = google_compute_global_address.storage_range.address
    peering_range_prefix = google_compute_global_address.storage_range.prefix_length
  }
}

#-----------------------------------------------------
# Parallelstore Outputs
#-----------------------------------------------------

output "parallelstore_instances" {
  description = "Map of Parallelstore instances per region with connection details and specifications"
  value = var.storage_type == "PARALLELSTORE" ? {
    for region, instance in module.parallelstore : region => {
      name          = instance.name_short
      instance_id   = instance.instance_id
      access_points = instance.access_points
      location      = instance.location
      region        = instance.region
      id            = instance.id
      capacity_gib  = instance.capacity_gib
      daos_version  = instance.daos_version
      kubernetes_usage = {
        persistent_volume_claim_template = "templates/parallelstore-pvc.yaml"
        csi_driver_enabled               = var.enable_csi_parallelstore
      }
    }
  } : {}
}

output "parallelstore_count" {
  description = "Total number of Parallelstore instances deployed"
  value       = length(module.parallelstore)
}

output "parallelstore_access_points" {
  description = "Map of regions to Parallelstore access points for client configuration"
  value = var.storage_type == "PARALLELSTORE" ? {
    for region, instance in module.parallelstore : region => instance.access_points
  } : {}
}

#-----------------------------------------------------
# Lustre Outputs
#-----------------------------------------------------

output "lustre_instances" {
  description = "Map of Lustre instances per region with connection details and specifications"
  value = var.storage_type == "LUSTRE" ? {
    for region, instance in module.lustre : region => {
      instance_id  = instance.instance_id
      mount_point  = instance.mount_point
      location     = instance.location
      region       = instance.region
      id           = instance.id
      capacity_gib = instance.capacity_gib
      filesystem   = instance.filesystem
      kubernetes_usage = {
        persistent_volume_claim_template = "templates/lustre-pvc.yaml"
        gke_support_enabled              = var.lustre_gke_support_enabled
      }
    }
  } : {}
}

output "lustre_count" {
  description = "Total number of Lustre instances deployed"
  value       = length(module.lustre)
}

output "lustre_mount_points" {
  description = "Map of regions to Lustre mount points for client configuration"
  value = var.storage_type == "LUSTRE" ? {
    for region, instance in module.lustre : region => instance.mount_point
  } : {}
}



#-----------------------------------------------------
# Identity and Security Outputs
#-----------------------------------------------------

output "cluster_service_account" {
  description = "Service account details used by GKE clusters for workload identity and resource access"
  value = {
    email       = google_service_account.cluster_service_account.email
    id          = google_service_account.cluster_service_account.id
    name        = google_service_account.cluster_service_account.name
    iam_binding = "serviceAccount:${google_service_account.cluster_service_account.email}"
  }
}

output "project_info" {
  description = "Information about the Google Cloud project where resources are deployed"
  value = {
    project_id     = data.google_project.environment.project_id
    project_name   = data.google_project.environment.name
    project_number = data.google_project.environment.number
  }
}

#-----------------------------------------------------
# Terraform Configuration Outputs
#-----------------------------------------------------

output "terraform_configuration" {
  description = "Summary of main Terraform configuration parameters used for this deployment"
  value = {
    project_id          = var.project_id
    regions             = var.regions
    storage_type        = var.storage_type
    storage_regions     = local.storage_locations_map
    clusters_per_region = var.clusters_per_region
    total_clusters      = length(module.gke_standard)
    total_storage       = length(module.parallelstore) + length(module.lustre)
    storage_details = {
      parallelstore_enabled = var.storage_type == "PARALLELSTORE"
      lustre_enabled        = var.storage_type == "LUSTRE"
      parallelstore_count   = length(module.parallelstore)
      lustre_count          = length(module.lustre)
      capacity_gib          = var.storage_capacity_gib
    }
    gke_config = {
      datapath_provider        = var.datapath_provider
      release_channel          = var.release_channel
      create_ondemand_nodepool = var.create_ondemand_nodepool
      create_spot_nodepool     = var.create_spot_nodepool
      mesh_certificates        = var.enable_mesh_certificates
      maintenance_window       = "${var.maintenance_start_time} to ${var.maintenance_end_time} (${var.maintenance_recurrence})"
    }
  }
}

output "helper_commands" {
  description = "Useful commands for working with the deployed infrastructure"
  value = {
    view_gke_clusters = "gcloud container clusters list --project ${var.project_id}"
    get_credentials   = length(module.gke_standard) > 0 ? "gcloud container clusters get-credentials ${var.gke_standard_cluster_name}-${var.regions[0]}-0 --region ${var.regions[0]} --project ${var.project_id}" : "No GKE clusters deployed"

    # Storage-related commands based on what's deployed
    storage_command = var.storage_type == "PARALLELSTORE" ? "gcloud parallelstore instances list --project ${var.project_id}" : (
      var.storage_type == "LUSTRE" ? "gcloud lustre instances list --project ${var.project_id}" : "No matching storage system deployed"
    )

    # Container registry commands
    docker_auth = "gcloud auth configure-docker ${module.artifact_registry.artifact_registry_region}-docker.pkg.dev"
    docker_push = "docker push ${module.artifact_registry.artifact_registry_url}/IMAGE:TAG"

    # Networking commands
    view_vpc = "gcloud compute networks describe ${google_compute_network.research-vpc.name} --project ${var.project_id}"
  }
}

#-----------------------------------------------------
# Troubleshooting and Diagnostics
#-----------------------------------------------------

output "diagnostics" {
  description = "Diagnostic information to help troubleshoot deployment issues"
  value = {
    deployment_state = {
      gke_clusters_deployed    = length(module.gke_standard) > 0 ? "Yes (${length(module.gke_standard)} clusters)" : "No"
      parallelstore_deployed   = length(module.parallelstore) > 0 ? "Yes (${length(module.parallelstore)} instances)" : "No"
      lustre_deployed          = length(module.lustre) > 0 ? "Yes (${length(module.lustre)} instances)" : "No"
      artifact_registry_region = module.artifact_registry.artifact_registry_region
    }
    regions_configuration = {
      requested_regions   = var.regions
      storage_locations   = local.storage_locations_map
      clusters_per_region = var.clusters_per_region
      actual_regions_covered = {
        gke_clusters = [for k, v in module.gke_standard : v.region]
        storage      = var.storage_type == "PARALLELSTORE" ? keys(module.parallelstore) : (var.storage_type == "LUSTRE" ? keys(module.lustre) : [])
      }
    }
    networking = {
      vpc_name              = google_compute_network.research-vpc.name
      vpc_mtu               = google_compute_network.research-vpc.mtu
      peering_range_name    = google_compute_global_address.storage_range.name
      peering_range_address = "${google_compute_global_address.storage_range.address}/${google_compute_global_address.storage_range.prefix_length}"
      regions_with_subnets  = keys(module.networking)
    }
  }
}
