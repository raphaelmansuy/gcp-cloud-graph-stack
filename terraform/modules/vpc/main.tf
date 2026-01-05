variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "enable_direct_egress" {
  type = bool
}

variable "labels" {
  type = map(string)
}

# Create VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.app_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  # labels not supported on google_compute_network in the selected provider version
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.app_name}-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  # labels not supported on google_compute_subnetwork in the selected provider version
}

# Create VPC Connector (for Serverless VPC Access, if not using Direct VPC egress)
resource "google_vpc_access_connector" "vpc_connector" {
  count = !var.enable_direct_egress ? 1 : 0

  name          = "${var.app_name}-vpc-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name

  machine_type = "f1-micro"
  min_instances = 2
  max_instances = 10

  # labels not supported on google_vpc_access_connector in the selected provider version

  depends_on = [google_compute_network.vpc]
}

# Firewall rule: Allow Cloud Run to reach PostgreSQL in VM
resource "google_compute_firewall" "allow_cloud_run_to_db" {
  name    = "${var.app_name}-allow-cloud-run-to-db"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = var.enable_direct_egress ? ["10.0.0.0/16"] : ["10.8.0.0/28"]
  target_tags   = ["postgresql"]

  # labels not supported on google_compute_firewall in the selected provider version
}

# Firewall rule: Allow SSH from compute metadata
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.app_name}-allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]

  # labels not supported on google_compute_firewall in the selected provider version
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "vpc_id" {
  value = google_compute_network.vpc.id
}

output "subnet_name" {
  value = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  value = google_compute_subnetwork.subnet.id
}

output "vpc_connector_name" {
  value = !var.enable_direct_egress ? google_vpc_access_connector.vpc_connector[0].name : null
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "router" {
  name    = "${var.app_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for internet egress from VPC
# This enables Cloud Run (via VPC connector) to reach external APIs like OpenAI
resource "google_compute_router_nat" "nat" {
  name                               = "${var.app_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "router_name" {
  value = google_compute_router.router.name
}

output "nat_name" {
  value = google_compute_router_nat.nat.name
}
