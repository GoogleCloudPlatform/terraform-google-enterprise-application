# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be created."
}

variable "region" {
  type        = string
  description = "The region of the build"
}

variable "repository_region" {
  type        = string
  description = "Artifacte Repository region"

}

variable "repository_id" {
  type        = string
  description = "Artifact repository ID"
}

variable "app_cloudbuild_workspace_cloudbuild_sa_email" {
  description = "Service Account to run Cloud Build Builds."
  type        = string
}

variable "workerpool_id" {
  description = <<-EOT
    Specifies the Cloud Build Worker Pool that will be utilized for triggers created in this step.

    The expected format is:
    `projects/PROJECT/locations/LOCATION/workerPools/POOL_NAME`.

    If you are using worker pools from a different project, ensure that you grant the
    `roles/cloudbuild.workerPoolUser` role on the workerpool project to the Cloud Build Service Agent and the Cloud Build Service Account of the trigger project:
    `service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `PROJECT_NUMBER@cloudbuild.gserviceaccount.com`
  EOT
  type        = string
  default     = null
}
