terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.19.0"
    }
  }
}

variable "application_name" {
  type        = string
  description = "The name of the application"
}

data "google_compute_network" "default" {
  name = "default"
}

resource "tls_private_key" "packer-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_service_account" "default" {
  account_id   = var.application_name
  display_name = "Custom SA for VM Instance"
}

resource "google_compute_instance" "default" {
  name         = var.application_name
  machine_type = "n2-standard-2"

  tags = ["golden-image"]

  metadata = {
    ssh-keys = "admin:${tls_private_key.packer-key.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = "rhel-9-v20250311"
      labels = {
        my_label = "value"
      }
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "NVME"
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}

output "server_ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}

output "ssh_connection" {
  value = "gcloud compute ssh --zone=us-central1-a ${google_compute_instance.default.name}"
}
