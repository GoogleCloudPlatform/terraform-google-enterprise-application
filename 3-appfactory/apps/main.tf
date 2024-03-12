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

module "app_01" {
  source = "../modules/app-group-baseline"

  application_name    = "app1"
  create_env_projects = true

  org_id          = var.org_id
  billing_account = var.billing_account
  folder_id       = var.common_folder_id
  envs            = var.envs
  cloudbuild_sa_roles = {
    development = {
      roles = ["roles/owner"]
    }
    non-production = {
      roles = ["roles/owner"]
    }
    production = {
      roles = ["roles/owner"]
    }
  }
}
