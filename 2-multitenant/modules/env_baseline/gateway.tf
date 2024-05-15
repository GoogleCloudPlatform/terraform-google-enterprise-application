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

locals {
  cluster_project_id = data.google_project.eab_cluster_project.project_id
  service_name       = "frontend.endpoints.${local.cluster_project_id}.cloud.goog"
}

data "template_file" "openapi_spec" {
  template = file("${path.module}/openapi_spec.yaml")

  vars = {
    endpoint_service = local.service_name
    target           = module.ip_address_frontend_ip.addresses[0]
  }
}

resource "google_endpoints_service" "default" {
  service_name   = local.service_name
  project        = local.cluster_project_id
  openapi_config = data.template_file.openapi_spec.rendered
}

resource "google_certificate_manager_certificate" "default" {
  project     = local.cluster_project_id
  name        = "mcg-cert"
  description = "The default cert"
  managed {
    domains = [
      local.service_name,
    ]
  }
}

resource "google_certificate_manager_certificate_map" "default" {
  project     = local.cluster_project_id
  name        = "mcg-cert-map"
  description = "gateway certificate map"
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  project      = local.cluster_project_id
  name         = "mcg-cert-map-entry"
  description  = "gateway certificate map entry"
  map          = google_certificate_manager_certificate_map.default.name
  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = local.service_name
}
