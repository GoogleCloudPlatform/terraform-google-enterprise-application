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
  env                           = "production"
  app_namespace                 = "transactions-production"
  app_service_account_name      = "bank-of-anthos"
  pod_service_account_principal = "principal://iam.googleapis.com/projects/${local.cluster_project_id}/locations/global/workloadIdentityPools/${local.cluster_project_number}.svc.id.goog/subject/ns/${local.app_namespace}/sa/${local.app_service_account_name}"
}

module "env" {
  source = "../../../../../modules/alloydb-psc-setup"

  env                         = local.env
  network_project_id          = var.network_project_id
  cluster_regions             = var.cluster_regions
  app_project_id              = var.app_project_id
  network_name                = var.network_name
  psc_consumer_fwd_rule_ip    = var.psc_consumer_fwd_rule_ip
  workload_identity_principal = local.pod_service_account_principal
}
