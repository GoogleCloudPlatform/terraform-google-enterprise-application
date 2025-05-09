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

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  workload_init_args = {
    for idx, args in var.workload_init_args :
    "job-${idx}-${substr(sha256(jsonencode(args)), 0, 10)}" => {
      args  = args,
      image = var.workload_image,
    }
  }

  parallelstore_templates = var.parallelstore_enabled ? fileset("${path.module}/k8s/parallelstore", "*.yaml.templ") : []

  parallelstore_configs = { for fname in local.parallelstore_templates : fname => {
    name          = "parallelstore-${replace(fname, ".yaml.templ", "")}"
    template_path = "${path.module}/k8s/parallelstore/${fname}"
  } }

  # Whether to enable different patterns
  enable_jobs = (var.gke_job_request != "" && var.gke_job_response != "") ? 1 : 0
  enable_hpa  = (var.gke_hpa_request != "" && var.gke_job_response != "") ? 1 : 0

  cluster_config = "${var.cluster_name}-${var.region}-${var.project_id}"

  kubeconfig_script = join("\n", [
    "export KUBECONFIG=\"${path.root}/generated/kubeconfig_${var.cluster_name}.yaml\"",
    "gcloud container clusters get-credentials ${var.cluster_name} --project=${var.project_id} --region=${var.region}",
    "mv -f \"${path.root}/generated/kubeconfig_${var.cluster_name}.yaml.${var.cluster_name}\" \"${path.root}/generated/kubeconfig_${var.cluster_name}.yaml\"",
  ])


  # Test output
  test_job_template = {
    for id, cfg in var.test_configs :
    id => templatefile(
      "${path.module}/k8s/agent_job.templ", {
        name              = "${replace(id, "/[_\\.]/", "-")}-worker",
        parallel          = cfg.parallel,
        workload_args     = var.workload_args,
        workload_image    = var.workload_image,
        agent_image       = var.agent_image,
        workload_endpoint = var.workload_grpc_endpoint,
        workload_request_sub = (cfg.parallel > 0 ?
          var.pubsub_job_request :
        var.pubsub_hpa_request)
        workload_response = (cfg.parallel > 0 ?
        var.gke_job_response : var.gke_hpa_response)
    })
  }

  test_controller_template = {
    for id, cfg in var.test_configs :
    id => templatefile(
      "${path.module}/k8s/controller_job.templ", {
        parallel       = 1,
        job_name       = "${replace(id, "/[_\\.]/", "-")}-controller",
        container_name = "controller",
        image          = var.agent_image,
        args = [
          "test", "pubsub",
          "--logJSON",
          "--logAll",
          "--jsonPubSub=true",
          (cfg.parallel > 0 ?
          var.gke_job_request : var.gke_hpa_request),
          (cfg.parallel > 0 ?
            var.pubsub_job_request :
          var.pubsub_hpa_request),
          "--source",
        cfg.testfile]
    })
  }

  test_shell = {
    for id, cfg in var.test_configs :
    id => templatefile(
      "${path.module}/k8s/test_config.sh.templ", {
        parallel          = cfg.parallel,
        job_config        = local.test_job_template[id],
        controller_config = local.test_controller_template[id],
        project_id        = var.project_id,
        region            = var.region,
        cluster_name      = var.cluster_name,
        KUBECONFIG        = "/tmp/kubeconfig_${var.cluster_name}-${var.project_id}.yaml"
    })
  }
}

# Apply configurations to the cluster
resource "null_resource" "cluster_init" {
  for_each = merge(
    { for fname in fileset(".", "${path.module}/k8s/*.yaml") : fname => file(fname) },
    { "volume_yaml" = templatefile(
      "${path.module}/k8s/volume.yaml.templ", {
        gcs_storage_data = var.gcs_bucket
      }),
      "hpa_yaml" = templatefile(
        "${path.module}/k8s/hpa.yaml.templ", {
          name                = "gke-hpa",
          workload_image      = var.workload_image,
          workload_args       = var.workload_args,
          workload_endpoint   = var.workload_grpc_endpoint,
          agent_image         = var.agent_image,
          gke_hpa_request_sub = var.pubsub_hpa_request
          gke_hpa_response    = var.gke_hpa_response
      }),
    }
  )

  triggers = {
    template       = each.value
    cluster_change = local.cluster_config
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}

    mkdir -p ${path.root}/generated/k8s_configs
    echo "${each.value}" > ${path.root}/generated/k8s_configs/${each.key}

    kubectl apply -f - <<EOF
    ${each.value}
    EOF
    EOT
  }
}

resource "null_resource" "apply_custom_compute_class" {
  triggers = {
    cluster_change = local.cluster_config
    kustomize_change = sha512(join("", [
      for f in fileset(".", "${path.module}/../../../../../kubernetes/compute-classes/**") :
      filesha512(f)
    ]))
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}
    kubectl apply -k "${path.module}/../../../../../kubernetes/compute-classes/"
    EOT
  }
}

resource "null_resource" "apply_custom_priority_class" {
  triggers = {
    cluster_change = local.cluster_config
    kustomize_change = sha512(join("", [
      for f in fileset(".", "${path.module}/../../../../../kubernetes/priority-classes/**") :
      filesha512(f)
    ]))
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}
    kubectl apply -k "${path.module}/../../../../../kubernetes/priority-classes/"
    EOT
  }
}

# Run workload initialization jobs
resource "null_resource" "job_init" {
  for_each = {
    for id, cfg in local.workload_init_args :
    id => templatefile("${path.module}/k8s/job.templ", {
      job_name       = replace(id, "/[_\\.]/", "-"),
      container_name = replace(id, "/[_\\.]/", "-"),
      parallel       = 1,
      image          = cfg.image,
      args           = cfg.args
    })
  }

  depends_on = [null_resource.cluster_init]

  triggers = {
    cluster_change = local.cluster_config
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}

    mkdir -p ${path.root}/generated/k8s_configs/job_init
    echo "${each.value}" > ${path.root}/generated/k8s_configs/job_init/${each.key}.yaml

    kubectl apply -f - <<EOF
    ${each.value}
    EOF

    while true; do
      echo "Checking status of job ${each.key}"
      if kubectl wait --for=condition=Complete --timeout=0 job/${each.key} 2> /dev/null; then
        echo "Job ${each.key} successful"
        exit 0
      fi
      if kubectl wait --for=condition=Failed --timeout=0 job/${each.key} 2> /dev/null; then
        echo "Job ${each.key} failed, logs follow:"
        kubectl logs -c ${each.key} --tail 10 "jobs/${each.key}"
        exit 1
      fi
      sleep 2
    done
    EOT
  }
}

# Parallelstore initialization
resource "null_resource" "parallelstore_init" {
  for_each = local.parallelstore_configs

  triggers = {
    template = templatefile(each.value.template_path, {
      name                = each.value.name
      access_points       = var.parallelstore_access_points
      project_id          = var.project_id
      vpc                 = var.parallelstore_vpc_name
      location            = var.parallelstore_location
      instance_name       = var.parallelstore_instance_name
      capacity            = var.parallelstore_capacity_gib
      workload_image      = var.workload_image
      workload_args       = var.workload_args
      workload_endpoint   = var.workload_grpc_endpoint
      agent_image         = var.agent_image
      gke_hpa_request_sub = var.pubsub_hpa_request
      gke_hpa_response    = var.gke_hpa_response
    })
    cluster_change = local.cluster_config
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}
    mkdir -p ${path.root}/generated/k8s_configs/parallelstore_init
    echo "${self.triggers.template}" > ${path.root}/generated/k8s_configs/parallelstore_init/${each.key}
    kubectl apply -f - <<EOF
    ${self.triggers.template}
    EOF
    EOT
  }
}

# Run workload initialization jobs
resource "null_resource" "parallelstore_job_init" {
  for_each = var.parallelstore_enabled ? {
    for id, cfg in local.workload_init_args :
    id => templatefile("${path.module}/k8s/parallelstore/job.templ", {
      job_name       = "parallelstore-${replace(id, "/[_\\.]/", "-")}"
      container_name = replace(id, "/[_\\.]/", "-")
      access_points  = var.parallelstore_access_points
      project_id     = var.project_id
      vpc            = var.parallelstore_vpc_name
      location       = var.parallelstore_location
      instance_name  = var.parallelstore_instance_name
      capacity       = var.parallelstore_capacity_gib
      parallel       = 1
      image          = cfg.image
      args           = cfg.args
    })
  } : {}

  depends_on = [null_resource.parallelstore_init]

  triggers = {
    cluster_change = local.cluster_config
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
    ${local.kubeconfig_script}
    mkdir -p ${path.root}/generated/k8s_configs/parallelstore_job_init
    echo "${each.value}" > ${path.root}/generated/k8s_configs/parallelstore_job_init/${each.key}.yaml
    kubectl apply -f - <<EOF
    ${each.value}
    EOF

    while true; do
      echo "Checking status of job parallelstore-${replace(each.key, "/[_\\.]/", "-")}"
      if kubectl wait --for=condition=Complete --timeout=0 job/parallelstore-${replace(each.key, "/[_\\.]/", "-")} 2> /dev/null; then
        echo "Job parallelstore-${replace(each.key, "/[_\\.]/", "-")} successful"
        exit 0
      fi
      if kubectl wait --for=condition=Failed --timeout=0 job/parallelstore-${replace(each.key, "/[_\\.]/", "-")} 2> /dev/null; then
        echo "Job parallelstore-${replace(each.key, "/[_\\.]/", "-")} failed, logs follow:"
        kubectl logs -c ${replace(each.key, "/[_\\.]/", "-")} --tail 10 "jobs/parallelstore-${replace(each.key, "/[_\\.]/", "-")}"
        exit 1
      fi
      sleep 2
    done
    EOT
  }
}
