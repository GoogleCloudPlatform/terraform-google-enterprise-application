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
  all_environments_cluster_service_accounts             = concat(local.dev_cluster_service_accounts, local.nonprod_cluster_service_accounts, local.prod_cluster_service_accounts)
  all_environments_cluster_service_accounts_iam_members = [for sa in local.all_environments_cluster_service_accounts : "serviceAccount:${sa}"]

  expanded_cluster_service_accounts = flatten([
    for key in keys(local.app_services) : [
      for sa in local.all_environments_cluster_service_accounts_iam_members : {
        app_name          = key
        cluster_sa_member = sa
      }
    ]
  ])
}

// Assign artifactregistry reader to cluster service accounts
// This allows docker images on application projects to be downloaded on the cluster
resource "google_folder_iam_member" "admin" {
  // for each app folder, create permissions for dev/non prod and prod cluster service accounts
  for_each = tomap({
    for app_name_sa in local.expanded_cluster_service_accounts : "${app_name_sa.app_name}.${app_name_sa.cluster_sa_member}" => app_name_sa
  })

  folder = google_folder.app_folder[each.value.app_name].name
  role   = "roles/artifactregistry.reader"
  member = each.value.cluster_sa_member
}
