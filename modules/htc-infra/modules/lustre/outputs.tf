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

output "id" {
  description = "Fully qualified identifier for the Lustre resource"
  value       = google_lustre_instance.lustre.id
}

output "name" {
  description = "Fully qualified name of the Lustre instance"
  value       = google_lustre_instance.lustre.name
}

output "instance_id" {
  description = "ID of the Lustre instance"
  value       = google_lustre_instance.lustre.instance_id
}

output "mount_point" {
  description = "List of IPv4 addresses or DNS names for the Lustre mount points"
  value       = google_lustre_instance.lustre.mount_point
}

output "location" {
  description = "Zone location where the Lustre instance is deployed"
  value       = google_lustre_instance.lustre.location
}

output "region" {
  description = "Region extracted from the location"
  value       = split("-", google_lustre_instance.lustre.location)[0]
}

output "capacity_gib" {
  description = "Provisioned storage capacity of the Lustre instance in GiB"
  value       = google_lustre_instance.lustre.capacity_gib
}

output "filesystem" {
  description = "Name of the Lustre filesystem"
  value       = google_lustre_instance.lustre.filesystem
}
