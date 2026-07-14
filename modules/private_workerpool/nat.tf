/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "google_compute_zones" "available" {
  region  = var.region
  project = var.project_id
  status  = "UP"
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  count                = var.create_nat ? 1 : 0
  project              = local.network_project_id
  peering              = google_service_networking_connection.gitlab_worker_pool_conn[0].peering
  network              = local.network_name
  import_custom_routes = true
  export_custom_routes = true
  // explicitly allow the peering for public ip address
  import_subnet_routes_with_public_ip = true
  export_subnet_routes_with_public_ip = true
}

resource "google_compute_subnetwork" "nat_subnet" {
  count         = var.create_nat ? 1 : 0
  project       = local.network_project_id
  name          = "nat-subnet"
  ip_cidr_range = local.nat_proxy_vm_ip_range

  private_ip_google_access = true

  region  = var.region
  network = local.network_id
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 18.0"

  count        = var.create_nat ? 1 : 0
  project_id   = local.network_project_id
  network_name = local.network_name

  rules = [{
    name                    = "allow-pool-to-nat"
    direction               = "INGRESS"
    priority                = 1000
    source_tags             = null
    source_service_accounts = null
    target_tags             = ["nat-gateway"]
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_range[0].address}/${google_compute_global_address.worker_range[0].prefix_length}"]

    allow = [{
      protocol = "all"
      ports    = null
    }]

    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    },
    {
      name          = "allow-icmp"
      description   = "Allow ICMP from anywhere"
      direction     = "INGRESS"
      priority      = 65534
      source_ranges = ["0.0.0.0/0"]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      allow = [{
        protocol = "icmp"
      }]
    }
  ]
}

resource "google_compute_address" "cloud_build_nat" {
  count        = var.create_nat ? 1 : 0
  project      = local.network_project_id
  address_type = "EXTERNAL"
  name         = "cloud-build-nat"
  network_tier = "PREMIUM"
  region       = var.region
}

resource "google_compute_instance" "vm_proxy" {
  count        = var.create_nat ? 1 : 0
  project      = local.network_project_id
  name         = "cloud-build-nat-vm"
  machine_type = "e2-medium"
  zone         = data.google_compute_zones.available.names[0]

  tags = ["direct-gateway-access", "nat-gateway"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network            = local.network_name
    subnetwork         = var.network_id == null ? module.vpc[0].subnets_names[0] : google_compute_subnetwork.nat_subnet[0].name
    subnetwork_project = local.network_project_id

    access_config {
      nat_ip = google_compute_address.cloud_build_nat[0].address
    }
  }

  can_ip_forward = true

  // This script configures the VM to do IP Forwarding
  metadata_startup_script = "sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING -o $(ip addr show scope global | head -1 | awk -F: '{print $2}') -j MASQUERADE"

  service_account {
    scopes = ["cloud-platform"]
  }
}

#  This route will route packets to the NAT VM

resource "google_compute_route" "through_nat" {
  count             = var.create_nat ? 1 : 0
  name              = "through-nat-range-1"
  project           = local.network_project_id
  dest_range        = "0.0.0.0/1"
  network           = local.network_name
  next_hop_instance = google_compute_instance.vm_proxy[0].id
  priority          = 10
}

resource "google_compute_route" "through_nat2" {
  count             = var.create_nat ? 1 : 0
  name              = "through-nat-range-2"
  project           = local.network_project_id
  dest_range        = "128.0.0.0/1"
  network           = local.network_name
  next_hop_instance = google_compute_instance.vm_proxy[0].id
  priority          = 10
}

# This route allow the NAT VM to reach the internet with it's external IP address

resource "google_compute_route" "direct_to_gateway" {
  count            = var.create_nat ? 1 : 0
  name             = "direct-to-gateway-range-1"
  project          = local.network_project_id
  dest_range       = "0.0.0.0/1"
  network          = local.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}

resource "google_compute_route" "direct_to_gateway2" {
  count            = var.create_nat ? 1 : 0
  name             = "direct-to-gateway-range-2"
  project          = local.network_project_id
  dest_range       = "128.0.0.0/1"
  network          = local.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}
