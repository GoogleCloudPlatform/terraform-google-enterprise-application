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

resource "google_service_account" "gitlab_vm" {
  account_id   = "gitlab-vm-sa"
  project      = local.project_id
  display_name = "Custom SA for VM Instance"
}

resource "google_project_iam_member" "secret_manager_admin_vm_instance" {
  project = local.project_id
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
    "roles/secretmanager.admin",
    "roles/privilegedaccessmanager.projectServiceAgent"
  ])
  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test[local.index].email}"
}

resource "google_compute_instance" "default" {
  name         = "gitlab"
  project      = local.project_id
  machine_type = "n2-standard-4"
  zone         = "us-central1-a"

  tags = ["git-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network            = module.vpc[local.index].network_name
    subnetwork         = module.vpc[local.index].subnets_names[0]
    subnetwork_project = local.project_id

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

  # depends_on = [time_sleep.wait_gitlab_project_apis]
}


resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = module.vpc[local.index].network_name
  project = local.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["git-vm"]

  # depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = module.vpc[local.index].network_name
  project = local.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["git-vm"]

  # depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_secret_manager_secret" "gitlab_webhook" {
  project   = local.project_id
  secret_id = "gitlab-webhook"
  replication {
    auto {}
  }

  # depends_on = [time_sleep.wait_gitlab_project_apis]
}

resource "google_secret_manager_secret_iam_member" "secret_iam_admin" {
  project   = local.project_id
  secret_id = google_secret_manager_secret.gitlab_webhook.secret_id
  role      = "roles/secretmanager.admin"
  member    = google_service_account.int_test[local.index].member
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
  value = local.project_number
}

output "gitlab_url" {
  value = "https://${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}.nip.io"
}

output "gitlab_internal_ip" {
  value = google_compute_instance.default.network_interface[0].network_ip
}

output "gitlab_secret_project" {
  value = local.project_id
}

output "gitlab_instance_zone" {
  value = google_compute_instance.default.zone
}

output "gitlab_instance_name" {
  value = google_compute_instance.default.name
}
