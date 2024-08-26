resource "google_compute_firewall" "allow_internal_ingress" {
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
  priority  = 1000
}

resource "google_compute_firewall" "allow_internal_egress" {
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

  direction = "EGRESS"
  priority  = 1000
}
