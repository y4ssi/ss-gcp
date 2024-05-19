resource "google_compute_network" "vpc_network" {
  name = "gke-vpc"
}

resource "google_container_cluster" "primary" {
  name     = "ss-gke-cluster"
  location = var.region

  network = google_compute_network.vpc_network.self_link

  remove_default_node_pool = true
  initial_node_count       = 1
  depends_on = [google_project_service.container_api,
  google_project_service.compute_api, google_project_service.cloudresourcemanager_api]
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "ss-node-pool"
  cluster  = google_container_cluster.primary.name
  location = var.region

  node_config {
    machine_type = var.machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  initial_node_count = 1

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
}