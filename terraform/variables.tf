variable "project_id" {
  type        = string
  description = "ID del proyecto de Google Cloud"
}

variable "name" {
  type    = string
  default = "pipeline-devops"
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "zone" {
  type    = string
  default = "southamerica-east1-a"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "machine_type" {
  type    = string
  default = "e2-small"
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}

variable "preemptible" {
  type        = bool
  default     = true
  description = "Nodos spot: hasta 80% más baratos (FinOps)"
}

variable "labels" {
  type    = map(string)
  default = { env = "test", owner = "zenon", cost-center = "coderhouse", auto-shutdown = "true" }
}
