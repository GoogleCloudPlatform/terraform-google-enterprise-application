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


output "region_mapping" {
  description = "Mapping of individual GCP regions to their corresponding multi-region parent (e.g., us-central1 → us), used for determining resource placement strategy"
  value       = local.region_mapping
}

output "region_counts" {
  description = "Count of specific regions within each multi-region group, used to determine the dominant multi-region and for resource distribution planning"
  value       = local.region_counts
}

output "dominant_region" {
  description = "The multi-region with the most regions in the input set (preferring US in case of ties), used for optimal placement of multi-region resources"
  value       = local.dominant_region
}

output "default_region" {
  description = "The first alphabetically sorted individual region from within the dominant multi-region, used as a default region for resources requiring a specific region"
  value       = local.default_region
}

output "regions_in_dominant" {
  description = "List of all individual regions that belong to the identified dominant multi-region, useful for distributing resources across zones within the preferred multi-region"
  value       = local.regions_in_dominant
}
