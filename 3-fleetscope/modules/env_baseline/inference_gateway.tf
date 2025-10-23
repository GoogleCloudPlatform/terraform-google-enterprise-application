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


module "inference_gateway_manifests" {
  for_each = var.enable_inference_gateway ? toset(var.cluster_membership_ids) : toset([])

  source = "../private_install_manifest"
  url                      = "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.0.0/manifests.yaml"
  project_id               = regex(local.fleet_membership_regex, each.value)[0]
  region                   = regex(local.fleet_membership_regex, each.value)[1]
  k8s_registry             = "registry.k8s.io"
  cluster_name             = regex(local.fleet_membership_regex, each.value)[2]
  cluster_region           = regex(local.fleet_membership_regex, each.value)[1]
  cluster_project          = regex(local.fleet_membership_regex, each.value)[0]
  cluster_service_accounts = var.cluster_service_accounts
  vpcsc_policy             = "ALLOW"
}

module "inference_gateway" {
  for_each = var.enable_inference_gateway ? toset(var.cluster_membership_ids) : toset([])

  source = "../private_install_manifest"
  url                                 = "https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/v1.0.0/config/crd/bases/inference.networking.x-k8s.io_inferenceobjectives.yaml"
  project_id                          = regex(local.fleet_membership_regex, each.value)[0]
  region                              = regex(local.fleet_membership_regex, each.value)[1]
  k8s_registry                        = "registry.k8s.io"
  cluster_name                        = regex(local.fleet_membership_regex, each.value)[2]
  cluster_region                      = regex(local.fleet_membership_regex, each.value)[1]
  cluster_project                     = regex(local.fleet_membership_regex, each.value)[0]
  cluster_service_accounts            = var.cluster_service_accounts
  vpcsc_policy                        = "ALLOW"
  create_k8s_remote_artifact_registry = false
  # depends_on                          = [module.inference_gateway_manifests]
}
