# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "ip_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.2"

  project_id   = var.cluster_project_id
  address_type = "EXTERNAL"
  region       = "global"
  global       = true
  names        = ["mcg-ip"]
}

module "cloud-ep-dns" {
  source  = "terraform-google-modules/endpoints-dns/google"
  version = "~> 3.0"

  project     = var.cluster_project_id
  name        = local.application_name
  external_ip = module.ip_address.addresses[0]
}

resource "google_certificate_manager_certificate" "default" {
  project     = var.cluster_project_id
  name        = "mcg-cert"
  description = "The default cert"
  labels = {
    "terraform" : true
  }
  managed {
    domains = [
      google_certificate_manager_dns_authorization.instance.domain,
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.instance.id,
    ]
  }
}

resource "google_certificate_manager_dns_authorization" "instance" {
  project     = var.cluster_project_id
  name        = "dns-auth"
  description = "The default dns"
  domain      = "${local.application_name}.endpoints.${var.cluster_project_id}.cloud.goog"
}

resource "google_certificate_manager_certificate_map" "default" {
  name        = "mcg-cert-map"
  project     = var.cluster_project_id
  description = "cymbal bank gateway certificate map"
  labels = {
    "terraform" : true
  }
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  project     = var.cluster_project_id
  name        = "mcg-cert-map-entry"
  description = "cymbal bank certificate map entry"
  map         = google_certificate_manager_certificate_map.default.name
  labels = {
    "terraform" : true
  }
  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = google_certificate_manager_dns_authorization.instance.domain
}
