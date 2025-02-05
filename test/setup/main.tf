/**
 * Copyright 2024-2025 Google LLC
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
  envs = (var.branch_name == "release-please--branches--main" || startswith(var.branch_name, "test-all/")) ? [
    "development",
    "nonproduction",
    "production",
  ] : ["development"]

  teams = setunion([
    "cb-frontend",
    "cb-accounts",
    "cb-ledger"],
    !var.single_project ? ["cymbalshops"] : []
  )

  index          = !var.single_project ? "multitenant" : "single_project"
  project_id     = [for i, value in merge(module.project, module.project_standalone) : value.project_id][0]
  project_number = [for i, value in merge(module.project, module.project_standalone) : value.project_number][0]
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
}

data "google_organization" "org" {
  organization = var.org_id
}

# Create google groups
module "group" {
  for_each = toset(local.teams)
  source   = "terraform-google-modules/group/google"
  version  = "~> 0.7"

  id           = "${each.key}-${random_string.prefix.result}@${data.google_organization.org.domain}"
  display_name = "${each.key}-${random_string.prefix.result}"
  description  = "Group module test group for ${each.key}"
  domain       = data.google_organization.org.domain
}
