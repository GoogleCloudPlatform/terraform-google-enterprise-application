provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "vllm_llama3" {
  count = var.enable_inference_gateway ? 1 : 0
  name  = "vllm-llama3-8b-instruct"

  repository = "oci://registry.k8s.io/gateway-api-inference-extension/charts"
  chart      = "inferencepool"

  version = "v1.0.1"

  namespace = "default"

  values = [
    yamlencode({
      inferencePool = {
        modelServers = {
          matchLabels = {
            app = "vllm-llama3-8b-instruct"
          }
        }
      }
      provider = {
        name = "gke"
      }
      inferenceExtension = {
        monitoring = {
          gke = {
            enabled = true
          }
        }
      }
    })
  ]
}
