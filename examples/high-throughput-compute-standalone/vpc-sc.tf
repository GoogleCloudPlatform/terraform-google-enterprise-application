resource "google_service_account" "cloudbuild_actor" {
  project      = var.project_id
  account_id   = "cloudbuild-actor"
  display_name = "Cloudbuild custom service account"
}

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members      = [google_service_account.cloudbuild_actor.member]
}
