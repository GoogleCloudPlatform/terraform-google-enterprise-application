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

output "primary_instance" {
  description = "primary instance created"
  value       = module.alloydb.primary_instance
}

output "primary_instance_id" {
  description = "ID of the primary instance created"
  value       = module.alloydb.primary_instance_id
}

output "primary_psc_attachment_link" {
  description = "The private service connect (psc) attachment created for primary instance"
  value       = module.alloydb.primary_psc_attachment_link
}

output "psc_dns_name" {
  description = "he DNS name of the instance for PSC connectivity. Name convention: ...alloydb-psc.goog"
  value       = module.alloydb.primary_instance.psc_instance_config[0].psc_dns_name
}

output "psc_consumer_fwd_rule_ip" {
  description = "Consumer psc endpoint created"
  value       = google_compute_address.psc_consumer_address.address
}
