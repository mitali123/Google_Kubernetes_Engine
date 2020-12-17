variable "project" { 
  default = "csye7125-297805"
}

variable "credentials_file" {
  default = "../secrets/terraform-user.json"
}

variable "region" {
  default = "us-east1"
}

variable "dbtier" {
  default = "db-f1-micro"
}

variable "disk_size"{
  type    = number
  default = 10
}

variable "database_version"{
  default = "MYSQL_5_7"
}

variable "db_user"{
  default = "admin"
}

variable "db_password" {
  default = "somethingstrong"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "cluster" {
  default = "gkecluster"
}

variable "min_node_count"{
 default = 3
}

variable "max_node_count"{
 default = 6
}

variable "max_unavailable"{
 default = 0
}

variable "max_surge"{
 default = 1
}

variable "node_machine_type"{
 default = "e2-standard-2"
}

variable "project_services" {
  type = "list"

  default = [
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com",
    "securetoken.googleapis.com",
  ]
  description = <<-EOF
  The GCP APIs that should be enabled in this project.
  EOF
}

variable "zone" {
  default = "us-east1-b"
  description = "The zone in which to create the Kubernetes cluster. Must match the region"
  type        = "string"
}


