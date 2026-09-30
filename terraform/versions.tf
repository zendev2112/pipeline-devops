terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
  # Estado remoto: crear el bucket una vez con scripts/tf-bootstrap.sh y descomentar
  # backend "gcs" {
  #   bucket = "pipeline-devops-tfstate"
  #   prefix = "gke"
  # }
}
