terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5, < 8"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
}
