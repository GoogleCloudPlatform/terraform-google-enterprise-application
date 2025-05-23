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

output "cluster_name" {
  description = "Name of the deployed GKE Standard cluster for use in kubectl commands and referencing in other resources"
  value       = google_container_cluster.risk-research.name
}

output "region" {
  description = "GCP region where the GKE Standard cluster is deployed, useful for region-scoped commands and resources"
  value       = var.region
}

output "endpoint" {
  description = "Control plane endpoint configuration for the GKE Standard cluster including DNS endpoints and external access configuration"
  value       = google_container_cluster.risk-research.control_plane_endpoints_config[0]
}

output "node_pools" {
  description = "Node pools created for the cluster"
  value = {
    ondemand_nodes = var.create_ondemand_nodepool ? google_container_node_pool.primary_ondemand_nodes[0].name : null
    spot_nodes     = var.create_spot_nodepool ? google_container_node_pool.primary_spot_nodes[0].name : null
  }
}

output "cluster_config" {
  description = "Configuration details for the GKE cluster"
  value = {
    datapath_provider      = var.datapath_provider
    release_channel        = var.release_channel
    mesh_certificates      = var.enable_mesh_certificates
    private_endpoint       = var.enable_private_endpoint
    workload_identity      = var.enable_workload_identity
    maintenance_recurrence = var.maintenance_recurrence
  }
}
