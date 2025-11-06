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

resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

data "google_project" "eab_cluster_project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "model_armor_service_network_extension_roles" {
  for_each = toset(["roles/compute.networkUser"])
  project  = var.network_project_id
  role     = each.value
  member   = "serviceAccount:${data.google_project.eab_cluster_project.number}@cloudservices.gserviceaccount.com"
}

resource "google_compute_subnetwork" "default" {
  name                       = "sb-load-balancer-${var.service_name}-${random_string.random.result}"
  project                    = var.network_project_id
  ip_cidr_range              = "10.1.2.0/24"
  network                    = var.vpc_id
  private_ipv6_google_access = "DISABLE_GOOGLE_ACCESS"
  purpose                    = "PRIVATE"
  region                     = var.region
  stack_type                 = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "proxy_only" {
  name          = "sb-proxy-only-${var.service_name}-${random_string.random.result}"
  project       = var.network_project_id
  ip_cidr_range = "10.129.0.0/23"
  network       = var.vpc_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  region        = var.region
  role          = "ACTIVE"
}

resource "google_compute_firewall" "default" {
  name    = "fw-allow-health-check-${var.service_name}-${random_string.random.result}"
  project = var.network_project_id
  allow {
    protocol = "tcp"
  }
  direction               = "INGRESS"
  network                 = var.vpc_id
  priority                = 1000
  source_ranges           = ["130.211.0.0/22", "35.191.0.0/16"]
  target_service_accounts = var.cluster_service_accounts
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_proxy" {
  name    = "fw-allow-proxies-${var.service_name}-${random_string.random.result}"
  project = var.network_project_id
  allow {
    ports    = ["443"]
    protocol = "tcp"
  }
  allow {
    ports    = ["80"]
    protocol = "tcp"
  }
  allow {
    ports    = ["8080"]
    protocol = "tcp"
  }
  direction               = "INGRESS"
  network                 = var.vpc_id
  priority                = 1000
  source_ranges           = ["10.129.0.0/23"]
  target_service_accounts = var.cluster_service_accounts
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_address" "default" {
  name         = "adr-load-balancer-${var.service_name}-${random_string.random.result}"
  project      = var.network_project_id
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = var.region
}

resource "google_compute_region_health_check" "default" {
  name               = "hck-l7-xlb-basic-check-${var.service_name}-${random_string.random.result}"
  project            = var.project_id
  check_interval_sec = 5
  healthy_threshold  = 2
  http_health_check {
    port_specification = "USE_SERVING_PORT"
    proxy_header       = "NONE"
    request_path       = "/health"
  }
  region              = var.region
  timeout_sec         = 5
  unhealthy_threshold = 2
  log_config {
    enable = true
  }
}

resource "google_compute_region_backend_service" "default" {
  name                  = "bs-l7-xlb-${var.service_name}-${random_string.random.result}"
  project               = var.project_id
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.default.id]
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 30

  dynamic "backend" {
    for_each = toset(var.group_endpoint)
    content {
      group                 = backend.value
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }

  log_config {
    enable = true
  }


}

resource "google_compute_region_url_map" "default" {
  name            = "url-map-regional-l7-xlb-${var.service_name}-${random_string.random.result}"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.default.id
  host_rule {
    hosts        = ["*"]
    path_matcher = "api-paths"
  }

  path_matcher {
    name = "api-paths"

    default_service = google_compute_region_backend_service.default.id
    path_rule {
      paths   = ["/v1/chat/completions", "/v1/chat/completions/*"]
      service = google_compute_region_backend_service.default.id
    }
  }
}

resource "google_compute_region_target_http_proxy" "default" {
  name    = "http-proxy-l7-xlb-${var.service_name}-${random_string.random.result}"
  project = var.project_id
  region  = var.region
  url_map = google_compute_region_url_map.default.id
}

resource "google_compute_forwarding_rule" "default" {
  name       = "fr-l7-xlb-${var.service_name}-${random_string.random.result}"
  project    = var.project_id
  provider   = google-beta
  depends_on = [google_compute_subnetwork.proxy_only]
  region     = var.region

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = var.vpc_id
  ip_address            = google_compute_address.default.id
  network_tier          = "STANDARD"
}
