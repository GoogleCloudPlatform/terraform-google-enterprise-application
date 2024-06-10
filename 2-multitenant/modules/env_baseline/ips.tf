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

// Create App/Ip Addresses
module "apps_ip_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 4.0"

  for_each = {
    for k, v in var.apps : k => v.ip_address_names
  }

  project_id   = data.google_project.eab_cluster_project.project_id
  address_type = "EXTERNAL"
  region       = "global"
  global       = true
  names        = each.value
}
