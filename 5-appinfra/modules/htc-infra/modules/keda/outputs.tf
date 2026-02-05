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

output "keda_images" {
  description = "KEDA image URLs including SHA digests, ready for Binary Authorization"
  value = {
    keda                   = data.google_artifact_registry_docker_image.keda_operator.self_link
    keda-metrics-apiserver = data.google_artifact_registry_docker_image.keda_api_server.self_link
  }

  depends_on = [
    null_resource.mirror_keda_images
  ]
}
