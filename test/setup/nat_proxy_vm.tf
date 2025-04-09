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
  single_project_network = {
    subnet_name           = "eab-develop-us-central1"
    subnet_ip             = "10.1.20.0/24"
    subnet_region         = "us-central1"
    subnet_private_access = true
  }
  single_project_secondary = {
    "eab-develop-us-central1" = [
      {
        range_name    = "eab-develop-us-central1-secondary-01"
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = "eab-develop-us-central1-secondary-02"
        ip_cidr_range = "192.168.64.0/18"
      },
  ] }
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id      = module.gitlab_project.project_id
  network_name    = "eab-vpc-workerpool"
  shared_vpc_host = false

  ingress_rules = [
    # {
    #   name     = "allow-ssh"
    #   priority = 65534
    #   log_config = {
    #     metadata = "INCLUDE_ALL_METADATA"
    #   }
    #   // IAP PROXY RANGE
    #   source_ranges = ["35.235.240.0/20"]
    #   allow = [
    #     {
    #       protocol = "tcp"
    #       ports    = ["22"]
    #     }
    #   ]
    # },
  ]

  subnets = concat([
    {
      subnet_name           = "nat-subnet"
      subnet_ip             = "10.1.1.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    },
    {
      subnet_name           = "gitlab-vm-subnet"
      subnet_ip             = "10.2.2.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    }
  ], var.single_project ? [local.single_project_network] : [])

  secondary_ranges = var.single_project ? local.single_project_secondary : {}
}

# resource "google_dns_policy" "default_policy" {
#   project                   = module.vpc.project_id
#   name                      = "dp-b-cbpools-default-policy"
#   enable_inbound_forwarding = true
#   enable_logging            = true
#   networks {
#     network_url = module.vpc.network_self_link
#   }
# }

# resource "google_compute_global_address" "google_services" {
#   name          = "google-services"
#   project       = module.vpc.project_id
#   purpose       = "VPC_PEERING"
#   address_type  = "INTERNAL"
#   address       = "10.2.0.0"
#   prefix_length = 24
#   network       = module.vpc.network_id
# }

# resource "google_service_networking_connection" "worker_pool_conn" {
#   network                 = module.vpc.network_id
#   service                 = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.google_services.name]
# }

# module "private_service_connect" {
#   source                     = "terraform-google-modules/network/google//modules/private-service-connect"
#   version                    = "~> 10.0"
#   project_id                 = module.vpc.project_id
#   network_self_link          = module.vpc.network_self_link
#   private_service_connect_ip = "10.3.0.5"
#   forwarding_rule_target     = "vpc-sc"
# }

resource "google_compute_network_peering_routes_config" "peering_routes" {
  project              = module.vpc.project_id
  peering              = google_service_networking_connection.gitlab_worker_pool_conn.peering
  network              = module.vpc.network_name
  import_custom_routes = true
  export_custom_routes = true
}

module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  project_id   = module.vpc.project_id
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
      name          = "default-allow-icmp"
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
  project      = module.vpc.project_id
  address_type = "EXTERNAL"
  name         = "cloud-build-nat"
  network_tier = "PREMIUM"
  region       = "us-central1"
}

resource "google_compute_instance" "vm-proxy" {
  project      = module.vpc.project_id
  name         = "cloud-build-nat-vm"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  tags = ["direct-gateway-access", "nat-gateway"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1404-trusty-v20160627"
    }
  }

  network_interface {
    network            = module.vpc.network_name
    subnetwork         = module.vpc.subnets_names[0]
    subnetwork_project = module.vpc.project_id

    access_config {
      nat_ip = google_compute_address.cloud_build_nat.address
    }
  }

  can_ip_forward = true

  metadata = {
    enable-oslogin = "true"
    startup-script = "sysctl -w net.ipv4.ip_forward=1\niptables -t nat -A POSTROUTING -o $(ip addr show scope global | head -1 | awk -F: '{print $2}') -j MASQUERADE"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_route" "through-nat1" {
  name              = "through-nat1"
  project           = module.vpc.project_id
  dest_range        = "0.0.0.0/1"
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm-proxy.id
  priority          = 10
}


resource "google_compute_route" "through-nat1" {
  name              = "through-nat1"
  project           = module.vpc.project_id
  dest_range        = "0.0.0.0/1"
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm-proxy.id
  priority          = 1000
}

resource "google_compute_route" "through-nat2" {
  project           = module.vpc.project_id
  name              = "through-nat2"
  dest_range        = "128.0.0.0/1"
  network           = module.vpc.network_name
  next_hop_instance = google_compute_instance.vm-proxy.id
  priority          = 1000
}

# resource "google_compute_route" "direct-to-gateway1" {
#   name             = "direct-to-gateway1"
#   project          = module.vpc.project_id
#   dest_range       = "0.0.0.0/1"
#   network          = module.vpc.network_name
#   next_hop_gateway = "default-internet-gateway"
#   tags             = ["direct-gateway-access"]
#   priority         = 10
# }

# resource "google_compute_route" "direct-to-gateway2" {
#   name             = "direct-to-gateway2"
#   project          = module.vpc.project_id
#   dest_range       = "128.0.0.0/1"
#   network          = module.vpc.network_name
#   next_hop_gateway = "default-internet-gateway"
#   tags             = ["direct-gateway-access"]
#   priority         = 10
# }
