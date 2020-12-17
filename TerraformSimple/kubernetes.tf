provider "google" { 
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
}

#VPC FOR GKE AND CLOUD SQL
resource "google_compute_network" "vpc_network" {
  name = "gke-sql-network"
}

#Private IP Address Within VPC
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

#GET GKE LATEST VERSION
data "google_container_engine_versions" "main" {
  provider = google-beta
  project = var.project
  location = var.region
  version_prefix = "1.18."
}

# GKE Cluster - Master Node
resource "google_container_cluster" "primary" {
  name     = var.cluster
  location = var.region
  remove_default_node_pool = true
  initial_node_count = 1
  network    = google_compute_network.vpc_network.name
  #min_master_version = "1.17.13-gke.1200"
  #subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
    addons_config {
      horizontal_pod_autoscaling {
          disabled = false
    }

}

//private_cluster_config{
//  enable_private_nodes = true
//  enable_private_endpoint = false
//  master_ipv4_cidr_block  = "172.16.0.16/28"
//}    
 
  // Specify the list of CIDRs which can access the master's API
//  master_authorized_networks_config {
//    cidr_blocks {
//      display_name = "bastion"
//      cidr_block   = format("%s/32", //google_compute_instance.bastion.network_interface.0.network_ip)
//    }
//  } 

  master_auth {
    username = var.gke_username
    password = var.gke_password

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

# GKE Cluster - Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes
  project    = var.project
  #version = "1.17.13-gke.1200"
autoscaling{
  min_node_count = var.min_node_count
  max_node_count = var.max_node_count
}
upgrade_settings{
  max_unavailable = var.max_unavailable
  max_surge = var.max_surge
}
  node_config {
    oauth_scopes = [

    ]

    labels = {
      env = var.project
    }


    preemptible  = false
    machine_type = var.node_machine_type
    tags         = ["gke-node", "${var.project}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }

  }

    depends_on = [
    "google_container_cluster.primary",
  ]
}

#Generate Random ID SQL Instance doesn't allow using instance name for a week after deletion
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "webapp-instance" {
	   name = "webapp-instance-${random_id.db_name_suffix.hex}"
	   database_version = var.database_version
	   region = var.region
	   depends_on = [google_service_networking_connection.private_vpc_connection]
	   deletion_protection = "false"
	   settings {
	   		ip_configuration{
	   			ipv4_enabled = "false"
	   			private_network = google_compute_network.vpc_network.id
	   		}
	   		tier = var.dbtier
	   		activation_policy =  "ALWAYS"
	   		disk_autoresize = "false"
	   		disk_size = var.disk_size
	   }
}

resource "google_sql_database" "webapp-database" {
  name     = "webapp"
  instance = google_sql_database_instance.webapp-instance.name
}

resource "google_sql_database_instance" "poller-instance" {
	   name = "poller-instance-${random_id.db_name_suffix.hex}"
	   database_version = var.database_version
	   region = var.region
	   depends_on = [google_service_networking_connection.private_vpc_connection]
	   deletion_protection = "false"
	   settings {
	   		ip_configuration{
	   			ipv4_enabled = "false"
	   			private_network = google_compute_network.vpc_network.id
	   		}
	   		tier = var.dbtier
	   		activation_policy =  "ALWAYS"
	   		disk_autoresize = "false"
	   		disk_size = var.disk_size
	   }
}

resource "google_sql_database" "poller-database" {
  name     = "poller"
  instance = google_sql_database_instance.poller-instance.name
}


resource "google_sql_database_instance" "notifier-instance" {
	   name = "notifier-instance-${random_id.db_name_suffix.hex}"
	   database_version = var.database_version
	   region = var.region
	   depends_on = [google_service_networking_connection.private_vpc_connection]
	   deletion_protection = "false"
	   settings {
	   		ip_configuration{
	   			ipv4_enabled = "false"
	   			private_network = google_compute_network.vpc_network.id
	   		}
	   		tier = var.dbtier
	   		activation_policy =  "ALWAYS"
	   		disk_autoresize = "false"
	   		disk_size = var.disk_size
	   }
}

resource "google_sql_database" "notifier-database" {
  name     = "notifier"
  instance = google_sql_database_instance.notifier-instance.name
}

resource "google_sql_user" "webapp-user" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.webapp-instance.name  
}

resource "google_sql_user" "poller-user" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.poller-instance.name
}

resource "google_sql_user" "notifier-user" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.notifier-instance.name
}

output "vpc_name"{
  value       = google_compute_network.vpc_network.name
  description = "Created VPC"
}

output "webapp_instances"{
  value       = google_sql_database_instance.webapp-instance.name
  description = "Created Webapp DB Instance"
}

output "webapp_instance_ip"{
  value       = google_sql_database_instance.webapp-instance.private_ip_address
  description = "Webapp Instance Private IP"
}

output "poller_instances"{
  value       = google_sql_database_instance.poller-instance.name
  description = "Created Poller DB Instance"
}

output "poller_instance_ip"{
  value       = google_sql_database_instance.poller-instance.private_ip_address
  description = "Poller Instance Private IP"
}

output "notifier_instances"{
  value       = google_sql_database_instance.notifier-instance.name
  description = "Created Notifier DB Instance"
}

output "notifier_instance_ip"{
  value       = google_sql_database_instance.notifier-instance.private_ip_address
  description = "Notifier Instance Private IP"
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Created GKE Cluster"
}

