/**
 * Copyright 2023 Google LLC
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

variable "proxy_name" {
  description = "Secure Web Proxy name."
  type        = string
  default     = "secure-web-proxy"
}

variable "project_id" {
  description = "The network project id where the SWP should be deployed."
  type        = string
}

variable "region" {
  description = "The region where the SWP should be deployed."
  type        = string
}

variable "network_id" {
  description = "The network id where the subnetwork, firewall rule and SWP should be deployed."
  type        = string
}

variable "subnetwork_id" {
  description = "The sub-network id where the SWP should be deployed."
  type        = string
}

variable "subnetwork_ip_range" {
  description = "The sub-network ip range."
  type        = string
}

variable "url_lists" {
  description = "A [URL list](https://cloud.google.com/secure-web-proxy/docs/url-list-syntax-reference) to allow access during Cloud Function build time."
  type        = list(string)
  default     = []
}

variable "certificates" {
  description = "Certificate id list to be used on the Secure Web Proxy Gateway."
  type        = list(string)
}

variable "addresses" {
  description = "IP address list to be used to access the Secure Web Proxy Gateway. Must be inside the range of the sub-network."
  type        = list(string)
}

variable "ports" {
  description = "Protocol port list to be used to access the Secure Web Proxy Gateway."
  type        = list(number)
}

variable "proxy_ip_range" {
  description = "The proxy sub-network ip range to be used by Secure Web Proxy Gateway. We recommend a subnet size of /23, or 512 proxy-only addresses."
  type        = string
}

variable "global_address_prefix_length" {
  description = "The prefix length of the IP range for the private service connect. Defaults to /16."
  type        = number
  default     = 16
}
