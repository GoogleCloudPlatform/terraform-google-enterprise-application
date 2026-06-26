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

locals {
  repository_prefix = "${var.repository_region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
  container_hash = {
    for container, config in var.containers :
    container => sha512(join("", concat([
      for f in fileset(config.source, "**/*") : fileexists("${config.source}/${f}") ? filesha512("${config.source}/${f}") : sha512("")
      ], [
      config.config_yaml == "" ? "" : sha512(config.config_yaml)
    ])))
  }
  container_tag = {
    for container, config in var.containers :
    container => "ver-${substr(local.container_hash[container], 0, 10)}"
  }
  container_image = {
    for container, config in var.containers :
    container => "${local.repository_prefix}/${container}:${local.container_tag[container]}"
  }
  container_status = {
    for container, config in var.containers :
    container => merge(config, {
      "tag"              = local.container_tag[container],
      "image"            = local.container_image[container],
      "hash"             = local.container_hash[container],
      "config_yaml_file" = config.config_yaml == "" ? "" : "config.yaml",
    })
  }
}

#
# Create Cloud Build staging bucket and grant permissions
#

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_storage_bucket" "cloudbuild" {
  project                     = var.project_id
  location                    = var.region
  name                        = "${var.project_id}-${var.region}-cloudbuild-${random_string.suffix.id}"
  uniform_bucket_level_access = true

  force_destroy = true
}


#
# Launch CloudBuild
#

resource "null_resource" "run_cloud_build" {
  for_each = var.containers

  triggers = {
    source_contents_hash = local.container_hash[each.key]
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT

    # Exit on any error
    set -e

    # Write to config.yaml
    if [ "${local.container_status[each.key].config_yaml_file}" != "" ]; then
    cat > "${each.value.source}/${local.container_status[each.key].config_yaml_file}" <<EOF
    ${each.value.config_yaml}
    EOF
    fi

    # Stage and build
    gcloud builds submit \
      --project ${var.project_id} \
      --region ${var.region} \
      --gcs-source-staging-dir gs://${google_storage_bucket.cloudbuild.id}/source/${each.key} \
      --gcs-log-dir gs://${google_storage_bucket.cloudbuild.id}/logs/${each.key} \
      --tag "${local.container_image[each.key]}" \
      --tag "${local.repository_prefix}/${each.key}:latest" \
      "${each.value.source}"

    # Remove config.yaml
    if [ "${local.container_status[each.key].config_yaml_file}" != "" ]; then
    rm "${each.value.source}/${local.container_status[each.key].config_yaml_file}"
    fi

    EOT
  }
}

data "google_artifact_registry_docker_image" "final_image" {
  for_each = var.containers

  depends_on = [null_resource.run_cloud_build]

  project       = var.project_id
  location      = var.repository_region
  repository_id = var.repository_id
  image_name    = each.key
}
