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

output "artifact_registry_url" {
  description = "Full URL of the Artifact Registry repository for use in Docker image references (format: {region}-docker.pkg.dev/{project}/{repository})"
  value       = "${module.region_analysis.dominant_region}-docker.pkg.dev/${data.google_project.environment.project_id}/${google_artifact_registry_repository.research-images.name}"
}

output "artifact_registry" {
  description = "Complete Artifact Registry repository resource including all attributes and properties"
  value       = google_artifact_registry_repository.research-images
}

output "artifact_registry_id" {
  description = "Fully qualified ID of the Artifact Registry repository in format projects/{project}/locations/{location}/repositories/{repository}"
  value       = google_artifact_registry_repository.research-images.id
}

output "artifact_registry_region" {
  description = "Region where the Artifact Registry repository was deployed based on dominant region analysis"
  value       = module.region_analysis.dominant_region
}
