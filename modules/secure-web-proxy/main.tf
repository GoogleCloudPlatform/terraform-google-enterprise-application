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

resource "google_compute_subnetwork" "swp_subnetwork_proxy" {
  name          = "sb-swp-${var.region}"
  ip_cidr_range = var.proxy_ip_range
  project       = var.project_id
  region        = var.region
  network       = var.network_id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

module "swp_firewall_rule" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "~> 9.0"
  project_id   = var.project_id
  network_name = var.network_id

  rules = [{
    name        = "fw-allow-tcp-443-egress-to-secure-web-proxy"
    description = "Allow Cloud Build to connect in Secure Web Proxy"
    direction   = "EGRESS"
    priority    = 100
    ranges      = [var.proxy_ip_range, var.subnetwork_ip_range]
    source_tags = []
    allow = [{
      protocol = "tcp"
      ports    = var.ports
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }]
}

resource "google_compute_global_address" "private_ip_allocation" {
  name          = "swp-cloud-function-internal-connection"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = var.global_address_prefix_length
  network       = var.network_id
}

resource "google_service_networking_connection" "private_service_connect" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_allocation.name]
  deletion_policy         = "ABANDON"

  depends_on = [
    google_compute_global_address.private_ip_allocation
  ]
}

resource "time_sleep" "wait_network_config_propagation" {
  create_duration  = "1m"
  destroy_duration = "2m"

  depends_on = [
    google_service_networking_connection.private_service_connect,
    google_compute_subnetwork.swp_subnetwork_proxy
  ]
}

resource "google_network_security_gateway_security_policy" "swp_security_policy" {
  name        = "swp-security-policy"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy security policy."
}

resource "google_network_security_url_lists" "swp_url_lists" {
  name        = "swp-url-lists"
  project     = var.project_id
  location    = var.region
  description = "Secure Web Proxy list of allowed URLs."
  values      = var.url_lists
}

resource "google_network_security_gateway_security_policy_rule" "swp_security_policy_rule" {
  name                    = "swp-security-policy-rule"
  project                 = var.project_id
  location                = var.region
  gateway_security_policy = google_network_security_gateway_security_policy.swp_security_policy.name
  enabled                 = true
  description             = "Secure Web Proxy security policy rule."
  priority                = 1
  session_matcher         = "inUrlList(host(), '${google_network_security_url_lists.swp_url_lists.id}')"
  tls_inspection_enabled  = false
  basic_profile           = "ALLOW"

  depends_on = [
    google_network_security_url_lists.swp_url_lists,
    google_network_security_gateway_security_policy.swp_security_policy
  ]
}

resource "google_network_services_gateway" "secure_web_proxy" {
  project                              = var.project_id
  name                                 = var.proxy_name
  location                             = var.region
  type                                 = "SECURE_WEB_GATEWAY"
  addresses                            = var.addresses
  ports                                = var.ports
  certificate_urls                     = var.certificates
  gateway_security_policy              = google_network_security_gateway_security_policy.swp_security_policy.id
  network                              = var.network_id
  subnetwork                           = var.subnetwork_id
  scope                                = "samplescope"
  delete_swg_autogen_router_on_destroy = true

  depends_on = [
    google_compute_subnetwork.swp_subnetwork_proxy,
    google_service_networking_connection.private_service_connect,
    google_network_security_gateway_security_policy_rule.swp_security_policy_rule
  ]
}

resource "time_sleep" "wait_secure_web_proxy" {
  create_duration = "2m"

  depends_on = [
    google_network_services_gateway.secure_web_proxy
  ]
}
