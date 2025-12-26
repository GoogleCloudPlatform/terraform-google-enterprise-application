
/**
 * Copyright 2024 Google LLC
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
  ca_bundle_base64 = base64encode(google_privateca_certificate_authority.custom_metrics_ca.pem_ca_certificates[0])
}

resource "google_privateca_ca_pool" "custom_metrics_ca_pool" {
  project  = var.cluster_project_id
  location = var.region
  name     = "custom-metrics-ca-pool"
  tier     = "DEVOPS"

  publishing_options {
    publish_ca_cert = true
    publish_crl     = false
  }
}

resource "google_privateca_certificate_authority" "custom_metrics_ca" {
  project                  = var.cluster_project_id
  location                 = var.region
  pool                     = google_privateca_ca_pool.custom_metrics_ca_pool.name
  certificate_authority_id = "custom-metrics-stackdriver-adapter-ca"
  lifetime                 = "31536000s" # 1 year
  deletion_protection      = false

  config {
    subject_config {
      subject {
        organization = "HTC Infra"
        common_name  = "custom-metrics-ca"
      }
    }
    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = false
          client_auth = false
        }
      }
    }
  }
  key_spec {
    algorithm = "RSA_PKCS1_4096_SHA256"
  }
}
