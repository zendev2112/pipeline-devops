resource "google_container_cluster" "this" {
  name                = "${var.name}-gke"
  location            = var.location
  network             = var.network
  subnetwork          = var.subnetwork
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  release_channel { channel = "REGULAR" }
  resource_labels = var.labels
}

resource "google_container_node_pool" "primary" {
  name     = "${var.name}-pool"
  cluster  = google_container_cluster.this.name
  location = var.location

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 30
    disk_type    = "pd-standard"
    preemptible  = var.preemptible
    labels       = var.labels
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    shielded_instance_config { enable_secure_boot = true }
  }
}
