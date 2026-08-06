
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

data "google_project" "environment" {
  project_id = var.project_id
}

module "region_analysis" {
  source  = "../region-analysis"
  regions = var.regions
}

# Artifact Registry
resource "google_artifact_registry_repository" "research-images" {
  project       = var.project_id
  location      = module.region_analysis.dominant_region
  repository_id = var.name
  description   = "Multi-region artifact registry in ${module.region_analysis.dominant_region}"
  format        = "DOCKER"
  # Keep only the most recent image versions based on cleanup_keep_count
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.cleanup_keep_count
    }
  }
  lifecycle {
    precondition {
      condition     = module.region_analysis.region_counts[module.region_analysis.dominant_region] > 0
      error_message = "Could not determine appropriate multi-region location from provided regions: ${jsonencode(var.regions)}"
    }
  }
}
