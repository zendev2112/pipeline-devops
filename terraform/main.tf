provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source      = "./modules/network"
  name        = var.name
  region      = var.region
  subnet_cidr = var.subnet_cidr
}

module "gke" {
  source       = "./modules/gke"
  name         = var.name
  location     = var.zone
  network      = module.network.network_name
  subnetwork   = module.network.subnet_name
  machine_type = var.machine_type
  min_nodes    = var.min_nodes
  max_nodes    = var.max_nodes
  preemptible  = var.preemptible
  labels       = var.labels
}
