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
  for_each = toset(local.expanded_cluster_service_accounts)

  folder = google_folder.app_folder[each.value.app_name].name
  role   = "roles/artifactregistry.reader"
  member = each.value.cluster_sa_member
}
