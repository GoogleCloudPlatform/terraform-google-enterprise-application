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
  k8s_provider_membership_regex = "projects/([^/]+)/locations/([^/]+)/memberships/([^/]+)"
  k8s_provider_cluster_project  = regex(local.k8s_provider_membership_regex, var.cluster_membership_id)[0]
  k8s_provider_cluster_region   = regex(local.k8s_provider_membership_regex, var.cluster_membership_id)[1]
  k8s_provider_cluster_name     = regex(local.k8s_provider_membership_regex, var.cluster_membership_id)[2]
}

data "google_project" "project" {
  project_id = local.k8s_provider_cluster_project
}

provider "kubernetes" {
  host = "https://${local.k8s_provider_cluster_region}-connectgateway.googleapis.com/v1/projects/${data.google_project.project.number}/locations/${local.k8s_provider_cluster_region}/gkeMemberships/${local.k8s_provider_cluster_name}"

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

resource "kubernetes_network_policy" "isolate_cb_frontend" {
  metadata {
    name      = "cymbal-bank-isolation"
    namespace = "cb-frontend-${var.env}"
  }

  spec {
    pod_selector {}
    policy_types = ["Egress", "Ingress"]

    ingress {
      # Allow all ingress
    }

    egress {
      # Allow all egress
    }
  }
}

resource "kubernetes_network_policy" "isolate_cb_ledger" {
  metadata {
    name      = "cymbal-bank-isolation"
    namespace = "cb-ledger-${var.env}"
  }

  spec {
    pod_selector {}
    policy_types = ["Egress", "Ingress"]

    ingress {
      from {
        namespace_selector {
          match_expressions {
            key      = "kubernetes.io/metadata.name"
            operator = "In"
            values   = ["cb-accounts-${var.env}", "cb-frontend-${var.env}"]
          }
        }
      }
    }

    egress {
      # Allow all egress
    }
  }
}

resource "kubernetes_network_policy" "isolate_cb_accounts" {
  metadata {
    name      = "cymbal-bank-isolation"
    namespace = "cb-accounts-${var.env}"
  }

  spec {
    pod_selector {}
    policy_types = ["Egress", "Ingress"]

    ingress {
      from {
        namespace_selector {
          match_expressions {
            key      = "kubernetes.io/metadata.name"
            operator = "In"
            values   = ["cb-frontend-${var.env}", "cb-ledger-${var.env}"]
          }
        }
      }
    }

    egress {
      # Allow all egress
    }
  }
}
