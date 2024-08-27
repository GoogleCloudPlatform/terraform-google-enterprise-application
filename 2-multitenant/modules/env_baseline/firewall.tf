resource "google_compute_firewall" "allow_internal_ingress" {
  count = var.add_cluster_firewall_rules ? 1 : 0

  name    = "allow-gke-ingress-ranges"
  project = var.network_project_id
  network = var.network_self_link

  source_ranges = [
    "10.0.0.0/8",
  ]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"
  priority  = 200
  # log_config {
  #   metadata = "INCLUDE_ALL_METADATA"
  # }
  target_tags = ["allow-gke-internal-ingress"]
}

resource "google_compute_firewall" "allow_internal_egress" {
  count = var.add_cluster_firewall_rules ? 1 : 0

  name    = "allow-gke-egress-ranges"
  project = var.network_project_id
  network = var.network_self_link

  destination_ranges = [
    "10.0.0.0/8",
  ]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
  # log_config {
  #   metadata = "INCLUDE_ALL_METADATA"
  # }
  direction   = "EGRESS"
  priority    = 200
  target_tags = ["allow-gke-internal-egress"]
}
