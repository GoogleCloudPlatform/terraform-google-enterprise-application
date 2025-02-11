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
 
module "gitlab_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"


  name                     = "eab-gitlab-self-hosted"
  random_project_id        = "true"
  random_project_id_length = 4
  org_id                   = var.org_id
  folder_id                = var.folder_id
  billing_account          = var.billing_account
  deletion_policy          = "DELETE"
  default_service_account  = "KEEP"

  auto_create_network = true

  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com"
  ]
}

resource "time_sleep" "wait_gitlab_project_apis" {
  depends_on = [module.gitlab_project]

  create_duration = "30s"
}

resource "google_service_account" "gitlab_vm" {
  account_id   = "gitlab-vm-sa"
  project      = module.gitlab_project.project_id
  display_name = "Custom SA for VM Instance"
}

resource "google_project_iam_member" "secret_manager_admin_vm_instance" {
  project = module.gitlab_project.project_id
  role    = "roles/secretmanager.admin"
  member  = google_service_account.gitlab_vm.member
}

resource "google_service_account_iam_member" "impersonate" {
  service_account_id = google_service_account.gitlab_vm.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.int_test[local.index].email}"
}

resource "google_project_iam_member" "int_test_gitlab_permissions" {
  for_each = toset([
    "roles/compute.instanceAdmin",
    "roles/secretmanager.admin"
  ])
  project = module.gitlab_project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test[local.index].email}"
}

resource "google_compute_instance" "default" {
  name         = "gitlab"
  project      = module.gitlab_project.project_id
  machine_type = "n2-standard-4"
  zone         = "us-central1-a"

  tags = ["git-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = file("./scripts/gitlab_self_hosted.sh")

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.gitlab_vm.email
    scopes = ["cloud-platform"]
  }

  depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"
  project = module.gitlab_project.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["git-vm"]

  depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"
  project = module.gitlab_project.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["git-vm"]

  depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_secret_manager_secret" "gitlab_webhook" {
  project   = module.gitlab_project.project_id
  secret_id = "gitlab-webhook"
  replication {
    auto {}
  }

  depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "random_uuid" "random_webhook_secret" {
}

resource "google_secret_manager_secret_version" "gitlab_webhook" {
  secret      = google_secret_manager_secret.gitlab_webhook.id
  secret_data = random_uuid.random_webhook_secret.result
}

output "gitlab_webhook_secret_id" {
  value = google_secret_manager_secret.gitlab_webhook.id
}

output "gitlab_pat_secret_name" {
  value = "gitlab-pat-from-vm"
}

output "gitlab_project_number" {
  value = module.gitlab_project.project_number
}

output "gitlab_url" {
  value = "https://${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}.nip.io"
}

output "gitlab_internal_ip" {
  value = google_compute_instance.default.network_interface[0].network_ip
}

output "gitlab_secret_project" {
  value = module.gitlab_project.project_id
}

output "gitlab_instance_zone" {
  value = google_compute_instance.default.zone
}

output "gitlab_instance_name" {
  value = google_compute_instance.default.name
}
