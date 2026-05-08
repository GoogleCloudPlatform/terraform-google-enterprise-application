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
  // Required to export the 0.0.0.0/1 and 128.0.0.0/1 NAT routes to the Cloud Build Worker Pool
  import_subnet_routes_with_public_ip = true
  export_subnet_routes_with_public_ip = true

  depends_on = [time_sleep.wait_api_propagation]
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 18.0"
  project_id   = module.private_workerpool_project.project_id
  network_name = module.vpc.network_name

  rules = [
    {
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
      name          = "allow-iap-ssh"
      description   = "Allow SSH from GCP IAP"
      direction     = "INGRESS"
      priority      = 65534
      source_ranges = ["35.235.240.0/20"]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
    }
  ]
}

resource "google_compute_address" "cloud_build_nat" {
  project      = module.private_workerpool_project.project_id
  address_type = "EXTERNAL"
  name         = "cloud-build-nat"
  network_tier = "PREMIUM"
  region       = var.workpool_region
}

resource "google_compute_instance" "vm_proxy" {
  project      = module.private_workerpool_project.project_id
  name         = "cloud-build-nat-vm"
  machine_type = "e2-medium"
  zone         = "${var.workpool_region}-a"

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
  // We explicitly use 'ens4' as it is the standard primary interface for GCP Debian images
  metadata_startup_script = "sysctl -w net.ipv4.ip_forward=1 && iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE"

  service_account {
    scopes = ["cloud-platform"]
  }
}

# ------------------------------------------------------------------------
# NOTE: Why 0.0.0.0/1 and 128.0.0.0/1 instead of 0.0.0.0/0?
#
# We cannot export a custom default route (0.0.0.0/0) over VPC peering to
# Google-managed services (like Cloud Build Private Pools). The peered
# network will ignore it in favor of its own internal default route.
# By splitting the internet into two /1 routes, we leverage Longest Prefix
# Match (LPM) routing. These routes are more specific than /0, so they are
# accepted over the peering connection, forcing Cloud Build worker traffic
# to route through our NAT VM.
# ------------------------------------------------------------------------

# This route will route packets to the NAT VM
resource "google_compute_route" "through_nat" {
  for_each = {
    "range1" = "0.0.0.0/1"
    "range2" = "128.0.0.0/1"
  }

  name              = "through-nat-${each.key}"
  project           = module.private_workerpool_project.project_id
  dest_range        = each.value
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm_proxy.id
  priority          = 10
}

# This route allows the NAT VM to reach the internet with its external IP address.
# It uses priority 5 (higher precedence than 10) and network tags so ONLY the
# NAT VM uses this route, preventing a routing loop.
resource "google_compute_route" "direct_to_gateway" {
  for_each = {
    "range1" = "0.0.0.0/1"
    "range2" = "128.0.0.0/1"
  }

  name             = "direct-to-gateway-${each.key}"
  project          = module.private_workerpool_project.project_id
  dest_range       = each.value
  network          = module.vpc.network_name
  next_hop_gateway = "default-internet-gateway"
  tags             = ["direct-gateway-access"]
  priority         = 5
}
