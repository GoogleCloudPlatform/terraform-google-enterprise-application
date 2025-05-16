resource "google_service_account" "cloudbuild_actor" {
  project      = var.project_id
  account_id   = "cloudbuild-actor"
  display_name = "Cloudbuild custom service account"
}

resource "google_service_account" "cloudrun_actor" {
  project      = var.project_id
  account_id   = "cloudrun-actor"
  display_name = "Cloud Run custom service account"
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_access_context_manager_access_level_condition" "access-level-conditions" {
  count        = var.access_level_name != null ? 1 : 0
  access_level = var.access_level_name
  members = concat(
    [google_service_account.cloudbuild_actor.member,
      google_service_account.cloudrun_actor.member
    ],
  ["serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"])
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "ingress_policy" {
  count     = var.service_perimeter_mode == "ENFORCE" ? 1 : 0
  perimeter = var.service_perimeter_name
  title     = "Ingress from 848655640797 to Storage API's"
  ingress_from {
    identity_type = "ANY_IDENTITY"
    sources {
      resource = "projects/848655640797"
    }
  }
  ingress_to {
    resources = ["*"]
    operations {
      service_name = "storage.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
    operations {
      service_name = "artifactregistry.googleapis.com"
      method_selectors {
        method = "*"
      }
    }
  }
  lifecycle {
    create_before_destroy = true
  }

}
