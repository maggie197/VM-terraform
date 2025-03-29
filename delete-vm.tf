resource "google_instance" "instance_vm" {
  provider     = google.delete
  name         = "instancevm"
  machine_type = "e2-medium"
  zone         = "europe-west2-b"
}