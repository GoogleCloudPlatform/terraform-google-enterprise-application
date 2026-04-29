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

output "reserved_ip_range" {
  description = "Identifier of the allocated IP address range associated with the Parallelstore private service access connection, used for network planning and troubleshooting"
  value       = google_parallelstore_instance.parallelstore.reserved_ip_range
}

output "daos_version" {
  description = "Version of the Distributed Application Object Storage (DAOS) software running in the Parallelstore instance, useful for compatibility checks and documentation"
  value       = google_parallelstore_instance.parallelstore.daos_version
}

output "id" {
  description = "Fully qualified identifier for the Parallelstore resource in format projects/{{project}}/locations/{{location}}/instances/{{instance_id}}, used in API calls and scripts"
  value       = google_parallelstore_instance.parallelstore.id
}

output "name" {
  description = "Fully qualified name of the Parallelstore instance in format projects/{{project}}/locations/{{location}}/instances/{{name}}, used in Google Cloud API calls"
  value       = google_parallelstore_instance.parallelstore.name
}

output "instance_id" {
  description = "ID of the Parallelstore instance"
  value       = google_parallelstore_instance.parallelstore.instance_id
}

output "access_points" {
  description = "List of IPv4 addresses for the Parallelstore access points, required for client-side configuration including Kubernetes PersistentVolumes and Daemonsets"
  value       = google_parallelstore_instance.parallelstore.access_points
}

output "location" {
  description = "Zone location where the Parallelstore instance is deployed (format: {region}-{zone}), important for co-locating with compute resources"
  value       = google_parallelstore_instance.parallelstore.location
}

output "region" {
  description = "Region extracted from the location"
  value       = split("-", google_parallelstore_instance.parallelstore.location)[0]
}

output "capacity_gib" {
  description = "Provisioned storage capacity of the Parallelstore instance in Gibibytes (GiB), useful for capacity planning and cost estimation"
  value       = google_parallelstore_instance.parallelstore.capacity_gib
}

output "name_short" {
  description = "Resource name in the format {{name}}"
  value       = var.instance_id != null ? var.instance_id : "parallelstore-${var.location}"
}
