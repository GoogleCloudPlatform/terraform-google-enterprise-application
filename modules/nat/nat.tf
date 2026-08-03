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

locals {
  network_id_splited = split("/", var.network_id)
  network_name       = local.network_id_splited[length(local.network_id_splited) - 1]
  network_project_id = regex("projects/([^/]*)/", var.network_id)[0]
}
data "google_compute_zones" "available" {
  region  = var.region
  project = local.network_project_id
  status  = "UP"
}

resource "google_compute_subnetwork" "nat_subnet" {
  project       = local.network_project_id
  name          = "sb-${var.region}-nat"
  ip_cidr_range = var.nat_proxy_vm_ip_range

  private_ip_google_access = true

  region  = var.region
  network = var.network_id
}

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 18.0"

  project_id   = local.network_project_id
  network_name = local.network_name

  rules = [
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
  project      = local.network_project_id
  address_type = "EXTERNAL"
  name         = "cloud-build-nat"
  network_tier = "PREMIUM"
  region       = var.region
}

resource "google_compute_instance" "vm_proxy" {
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
    subnetwork         = google_compute_subnetwork.nat_subnet.name
    subnetwork_project = local.network_project_id

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

resource "google_compute_route" "through_nat" {
  name              = "through-nat-range-1"
  project           = local.network_project_id
  dest_range        = "0.0.0.0/1"
  network           = local.network_name
  next_hop_instance = google_compute_instance.vm_proxy.id
  priority          = 10
}

resource "google_compute_route" "through_nat2" {
  name              = "through-nat-range-2"
  project           = local.network_project_id
  dest_range        = "128.0.0.0/1"
  network           = local.network_name
  next_hop_instance = google_compute_instance.vm_proxy.id
  priority          = 10
}

# This route allow the NAT VM to reach the internet with it's external IP address

resource "google_compute_route" "direct_to_gateway" {
  name             = "direct-to-gateway-range-1"
  project          = local.network_project_id
  dest_range       = "0.0.0.0/1"
  network          = local.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}

resource "google_compute_route" "direct_to_gateway2" {
  name             = "direct-to-gateway-range-2"
  project          = local.network_project_id
  dest_range       = "128.0.0.0/1"
  network          = local.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}
