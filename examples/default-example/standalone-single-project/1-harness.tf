/**
 * Copyright 2026 Google LLC
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

module "standalone_harness" {
  source = "../../../modules/standalone-harness"

  project_id                                    = var.project_id
  vpc_name                                      = "eab-hello-world-cluster"
  region                                        = var.region
  workerpool_id                                 = var.workerpool_id
  network_id                                    = var.network_id
  create_nat                                    = var.create_nat
  enables_network_connection_and_peering_routes = var.enables_network_connection_and_peering_routes
  logging_bucket                                = var.logging_bucket
  additional_services                           = []
  enable_proxy_subnet                           = true
  attestation_repository_name                   = "ar-eab-hello-world-binauthz"
  private_workerpool_name                       = "wp-eab-default-example"
  ncc_config                                    = var.ncc_config

  build_image_module_dependencies = concat([
    for i in google_access_context_manager_service_perimeter_dry_run_ingress_policy.private_workerpool_deployment : i.id],
    [for i in google_access_context_manager_service_perimeter_ingress_policy.private_workerpool_deployment : i.id],
  )
}
