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



data "google_compute_network_endpoint_group" "agent_neg" {
  for_each = local.cluster_zones
  project  = local.cluster_projects_id[each.value.env]
  zone     = each.value.zone
  name     = "capital-agent-neg"
}

module "regional_load_balancer" {
  source   = "../../modules/regional_load_balancer"
  for_each = local.cluster_projects_id

  vpc_id                   = "projects/${local.network_projects_id[each.key]}/global/networks/${local.network_names[each.key]}"
  project_id               = each.value
  network_project_id       = local.network_projects_id[each.key]
  region                   = var.region
  group_endpoint           = [for i, v in data.google_compute_network_endpoint_group.agent_neg : v.self_link if strcontains(i, each.key)]
  service_name             = local.service_name
  cluster_service_accounts = [for i, sa in local.cluster_service_accounts : sa if strcontains(i, each.key)]
}



resource "null_resource" "create_service_extension" {
  for_each = module.regional_load_balancer

  triggers = {
    location = var.region
    project  = local.cluster_projects_id[each.key]
    file     = data.template_file.url_map_config[each.key].rendered
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud service-extensions lb-traffic-extensions import traffic-ext \
      --location=${self.triggers.location} \
      --project=${self.triggers.project} \
      --source=- <<CONFIG
      ${data.template_file.url_map_config[each.key].rendered}
      CONFIG
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      gcloud service-extensions lb-traffic-extensions delete traffic-ext \
      --location=${self.triggers.location} \
      --project=${self.triggers.project}
    EOT
  }
}

data "template_file" "url_map_config" {
  for_each = module.regional_load_balancer
  template = file("${path.module}/traffic_callout_service.yaml")

  # Variáveis a serem injetadas no template YAML
  vars = {
    url_map_name    = "traffic_callout_service_${var.region}"
    forwarding_rule = each.value.forwarding_rule_id
    project_id      = local.cluster_projects_id[each.key]
    region          = var.region
    # model_name              = "meta-llama/Llama-3.1-8B-Instruct"
    model_name              = "gemini-2.0-flash"
    model_armor_template_id = module.model_armor_configuration[each.key].template.id
  }
}
