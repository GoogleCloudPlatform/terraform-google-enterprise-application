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



resource "google_compute_network_peering_routes_config" "peering_routes" {
  project              = module.private_workerpool_project.project_id
  peering              = google_service_networking_connection.gitlab_worker_pool_conn.peering
  network              = module.vpc.network_name
  import_custom_routes = true
  export_custom_routes = true
  // explicitly allow the peering for public ip address
  import_subnet_routes_with_public_ip = true
  export_subnet_routes_with_public_ip = true

  depends_on = [time_sleep.wait_api_propagation]
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  project_id   = module.private_workerpool_project.project_id
  network_name = module.vpc.network_name

  rules = [{
    name                    = "allow-pool-to-nat"
    direction               = "INGRESS"
    priority                = 1000
    source_tags             = null
    source_service_accounts = null
    target_tags             = ["nat-gateway"]
    target_service_accounts = null

    ranges = ["${google_compute_global_address.worker_range.address}/${google_compute_global_address.worker_range.prefix_length}"]

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
  project      = module.private_workerpool_project.project_id
  address_type = "EXTERNAL"
  name         = "cloud-build-nat"
  network_tier = "PREMIUM"
  region       = "us-central1"
}

resource "google_compute_instance" "vm-proxy" {
  project      = module.private_workerpool_project.project_id
  name         = "cloud-build-nat-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  tags = ["direct-gateway-access", "nat-gateway"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network            = module.vpc.network_name
    subnetwork         = module.vpc.subnets_names[0]
    subnetwork_project = module.private_workerpool_project.project_id

    access_config {
      nat_ip = google_compute_address.cloud_build_nat.address
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

resource "google_compute_route" "through-nat" {
  name              = "through-nat-range1"
  project           = module.private_workerpool_project.project_id
  dest_range        = "0.0.0.0/1"
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm-proxy.id
  priority          = 10
}

resource "google_compute_route" "through-nat2" {
  name              = "through-nat-range2"
  project           = module.private_workerpool_project.project_id
  dest_range        = "128.0.0.0/1"
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm-proxy.id
  priority          = 10
}

# This route allow the NAT VM to reach the internet with it's external IP address

resource "google_compute_route" "direct-to-gateway" {
  name             = "direct-to-gateway-range1"
  project          = module.private_workerpool_project.project_id
  dest_range       = "0.0.0.0/1"
  network          = module.vpc.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}

resource "google_compute_route" "direct-to-gateway2" {
  name             = "direct-to-gateway-range2"
  project          = module.private_workerpool_project.project_id
  dest_range       = "128.0.0.0/1"
  network          = module.vpc.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}
