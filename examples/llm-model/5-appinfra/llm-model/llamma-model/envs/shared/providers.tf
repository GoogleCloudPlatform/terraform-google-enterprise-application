
provider "google" {
	impersonate_service_account = "tf-cb-llamma-model-i-r@llm-llamma-model-admin-t2e5.iam.gserviceaccount.com"
}

provider "google-beta" {
	impersonate_service_account = "tf-cb-llamma-model-i-r@llm-llamma-model-admin-t2e5.iam.gserviceaccount.com"
}
			