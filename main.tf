provider "google" {
  credentials = file("terraform-key.json")
  project = "megija-terraform-project"    # project id
  region  = "europe-west2"      # add region  
  zone    = "europe-west2-b"    # add zone
}

resource "google_compute_instance" "instancevm" {
  name         = "instancevm"
  machine_type = "e2-medium"
  zone         = "europe-west2-b"   # ad zone

  tags = ["http-server", "https-server", "ssh-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"  # Use Ubuntu 22.04 LTS
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {}  
  }

  metadata = {
    enable-osconfig = "TRUE"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "null_resource" "delete_ssh_firewall" {
  provisioner "local-exec" {
    command = "gcloud compute firewall-rules delete allow-ssh --quiet"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "google_compute_firewall" "allow_ssh" {
depends_on = [null_resource.delete_ssh_firewall]  # Ensures the delete command runs first

  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  lifecycle {
    ignore_changes = [name]
  }
}
