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

data "google_project" "environment" {
  project_id = var.project_id
}

data "google_compute_regions" "available" {
  project = data.google_project.environment.project_id
}

# Get available zones for the region
data "google_compute_zones" "available" {
  project = data.google_project.environment.project_id
  region  = var.region
}

# Random zone selection
resource "random_shuffle" "zone" {
  input        = data.google_compute_zones.available.names
  result_count = 3
}

data "google_container_engine_versions" "central1b" {
  provider       = google-beta
  location       = var.region
  version_prefix = var.min_master_version
  project        = var.project_id
}

resource "google_container_cluster" "risk-research" {
  deletion_protection = false
  provider            = google-beta
  name                = var.cluster_name
  project             = var.project_id
  location            = var.region
  datapath_provider   = var.datapath_provider
  node_locations      = [random_shuffle.zone.result[0], random_shuffle.zone.result[1], random_shuffle.zone.result[2]]
  depends_on          = [google_kms_crypto_key_iam_member.gke_crypto_key]
  min_master_version  = data.google_container_engine_versions.central1b.latest_master_version

  # We do this to ensure we have large control plane nodes created initially
  initial_node_count       = var.scaled_control_plane ? 700 : 1
  remove_default_node_pool = true

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  node_config {
    service_account = var.cluster_service_account.email
    shielded_instance_config {
      enable_secure_boot          = var.enable_secure_boot
      enable_integrity_monitoring = var.enable_shielded_nodes
    }
    machine_type = "e2-standard-2"
    preemptible  = false
  }

  network    = var.network
  subnetwork = var.subnet

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke-key.id
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = cidrsubnet("100.64.0.0/16", 12, index(data.google_compute_regions.available.names, var.region) * 4 + var.cluster_index) # /28 blocks index
    # Enables access to the control plane from any network
    master_global_access_config {
      enabled = true
    }
  }

  # Custom maintenance window
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  enable_intranode_visibility              = var.enable_intranode_visibility
  enable_cilium_clusterwide_network_policy = var.enable_cilium_clusterwide_network_policy

  monitoring_config {
    # Only enable advanced datapath observability when ADVANCED_DATAPATH is selected
    dynamic "advanced_datapath_observability_config" {
      for_each = var.datapath_provider == "ADVANCED_DATAPATH" ? [1] : []
      content {
        enable_metrics = var.enable_advanced_datapath_observability_metrics
        enable_relay   = var.enable_advanced_datapath_observability_relay
      }
    }

    enable_components = [
      "SYSTEM_COMPONENTS",
      "STORAGE",
      "POD",
      "DEPLOYMENT",
      "STATEFULSET",
      "DAEMONSET",
      "HPA",
      "CADVISOR",
      "KUBELET",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER"
    ]
    managed_prometheus {
      enabled = true
    }
  }
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER",
      "WORKLOADS"
    ]
  }

  ip_allocation_policy {
    stack_type                    = "IPV4"
    services_secondary_range_name = var.ip_range_services
    cluster_secondary_range_name  = var.ip_range_pods
  }

  workload_identity_config {
    workload_pool = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
  }

  node_pool_defaults {

    node_config_defaults {
      logging_variant = "MAX_THROUGHPUT"
      gcfs_config {
        enabled = true
      }
    }
  }

  # Support for mTLS
  mesh_certificates {
    enable_certificates = var.enable_mesh_certificates
  }

  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = var.enable_csi_filestore
    }
    gcs_fuse_csi_driver_config {
      enabled = var.enable_csi_gcs_fuse
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    dns_cache_config {
      enabled = true
    }
    parallelstore_csi_driver_config {
      enabled = var.enable_csi_parallelstore
    }
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"

    resource_limits {
      resource_type = "cpu"
      minimum       = 4
      maximum       = var.cluster_max_cpus
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 16
      maximum       = var.cluster_max_memory
    }

    resource_limits {
      resource_type = "nvidia-a100-80gb"
      maximum       = 30
    }

    resource_limits {
      resource_type = "nvidia-l4"
      maximum       = 30
    }

    resource_limits {
      resource_type = "nvidia-tesla-t4"
      maximum       = 300
    }

    resource_limits {
      resource_type = "nvidia-tesla-a100"
      maximum       = 50
    }

    resource_limits {
      resource_type = "nvidia-tesla-k80"
      maximum       = 30
    }

    resource_limits {
      resource_type = "nvidia-tesla-p4"
      maximum       = 30
    }

    resource_limits {
      resource_type = "nvidia-tesla-p100"
      maximum       = 30
    }

    resource_limits {
      resource_type = "nvidia-tesla-v100"
      maximum       = 30
    }

    auto_provisioning_defaults {
      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_integrity_monitoring = true
        enable_secure_boot          = true
      }

      upgrade_settings {
        strategy        = "SURGE"
        max_surge       = 1
        max_unavailable = 0
      }
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      service_account = var.cluster_service_account.email
    }
  }
  release_channel {
    channel = var.release_channel
  }

  secret_manager_config {
    enabled = true
  }

  pod_autoscaling {
    hpa_profile = "PERFORMANCE"
  }

  lifecycle {

    # Once deleted the node_config will change. We can ignore this.
    ignore_changes = [
      node_config,
      maintenance_policy
    ]
  }
}


resource "google_container_node_pool" "primary_ondemand_nodes" {
  count          = var.create_ondemand_nodepool ? 1 : 0
  name           = "ondemand-node-1"
  provider       = google-beta
  project        = var.project_id
  location       = var.region
  cluster        = google_container_cluster.risk-research.name
  node_locations = [random_shuffle.zone.result[0], random_shuffle.zone.result[1], random_shuffle.zone.result[2]]

  autoscaling {
    location_policy      = "ANY"
    total_min_node_count = var.min_nodes_ondemand
    total_max_node_count = var.max_nodes_ondemand
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }


  node_config {
    logging_variant = "MAX_THROUGHPUT"
    shielded_instance_config {
      enable_integrity_monitoring = var.enable_shielded_nodes
      enable_secure_boot          = var.enable_secure_boot
    }

    preemptible  = false
    machine_type = var.node_machine_type_ondemand

    labels = {
      "resource-model" : "n2"
      "resource-type" : "cpu"
      "billing-type" : "on-demand"
    }
    gvnic {
      enabled = true
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.cluster_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

resource "google_container_node_pool" "primary_spot_nodes" {
  count              = var.create_spot_nodepool ? 1 : 0
  name               = "spot-nodes-1"
  provider           = google-beta
  project            = var.project_id
  location           = var.region
  cluster            = google_container_cluster.risk-research.name
  node_locations     = [random_shuffle.zone.result[0], random_shuffle.zone.result[1], random_shuffle.zone.result[2]]
  initial_node_count = 5


  autoscaling {
    location_policy      = "ANY"
    total_min_node_count = var.min_nodes_spot
    total_max_node_count = var.max_nodes_spot
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    logging_variant = "MAX_THROUGHPUT"
    shielded_instance_config {
      enable_integrity_monitoring = var.enable_shielded_nodes
      enable_secure_boot          = var.enable_secure_boot
    }

    preemptible  = true
    machine_type = var.node_machine_type_spot

    labels = {
      "resource-model" : "n2"
      "resource-type" : "cpu"
      "billing-type" : "spot"
      "cloud.google.com/compute-class" : "spot-capacity"
    }

    taint {
      key    = "cloud.google.com/compute-class"
      value  = "spot-capacity"
      effect = "NO_SCHEDULE"
    }

    gvnic {
      enabled = true
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.cluster_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  lifecycle {
    ignore_changes = [
      node_config,
      initial_node_count
    ]
  }
}

# KMS for Encryption

resource "random_string" "random" {
  length           = 5
  special          = true
  override_special = "_-"
}

resource "google_kms_key_ring" "gke-keyring" {
  name     = "${var.cluster_name}-${random_string.random.id}"
  project  = data.google_project.environment.project_id
  location = var.region
}

resource "google_kms_crypto_key" "gke-key" {
  name            = "${var.cluster_name}-key"
  key_ring        = google_kms_key_ring.gke-keyring.id
  rotation_period = "7776000s"
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_kms_crypto_key_iam_member" "gke_crypto_key" {
  crypto_key_id = google_kms_crypto_key.gke-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.environment.number}@container-engine-robot.iam.gserviceaccount.com"
}
