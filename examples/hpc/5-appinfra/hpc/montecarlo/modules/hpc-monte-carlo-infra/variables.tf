variable "infra_project" {
  type = string
}

variable "cluster_project" {
  type = string
}

variable "region" {
  type = string
}

variable "bucket_force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects. If false, Terraform will fail to delete buckets which contain objects."
  type        = bool
  default     = false
}

variable "cluster_project_number" {
  type = string
}

variable "env" {
  type = string
}

variable "cluster_service_accounts" {
  type = map(any)
}