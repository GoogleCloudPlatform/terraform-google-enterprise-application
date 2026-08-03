/**
 * Copyright 2025 Google LLC
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

variable "network_id" {
  description = "The network id where NAT will be created."
  type        = string
}

variable "region" {
  description = "The region where NAT will be created."
  type        = string
}

variable "nat_proxy_vm_ip_range" {
  description = "IP Range for NAT proxy machine."
  type        = string
}
