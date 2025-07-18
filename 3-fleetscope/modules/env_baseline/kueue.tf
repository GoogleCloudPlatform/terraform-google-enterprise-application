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
  fleet_membership_regex = "projects/([^/]+)/locations/([^/]+)/memberships/([^/]+)"
  kueue_version          = "v0.10.1"
}

module "kueue" {
  for_each = var.enable_kueue ? toset(var.cluster_membership_ids) : toset([])

  source                   = "../private_install_manifest"
  url                      = "https://github.com/kubernetes-sigs/kueue/releases/download/${local.kueue_version}/manifests.yaml"
  project_id               = regex(local.fleet_membership_regex, each.value)[0]
  region                   = "us-central1"
  k8s_registry             = "registry.k8s.io"
  cluster_name             = regex(local.fleet_membership_regex, each.value)[2]
  cluster_region           = regex(local.fleet_membership_regex, each.value)[1]
  cluster_project          = regex(local.fleet_membership_regex, each.value)[0]
  cluster_service_accounts = var.cluster_service_accounts
  vpcsc_policy             = "ALLOW"
}
