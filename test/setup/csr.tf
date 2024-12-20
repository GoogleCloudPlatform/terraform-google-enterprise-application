# DEPRECATED - TODO: Remove after CSR support is removed
resource "google_sourcerepo_repository" "app_repo" {

  project = local.project_id
  name    = "eab-default-example-hello-world"

  create_ignore_already_exists = true
}
