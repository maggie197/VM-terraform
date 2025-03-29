resource "google_compute_instance" "instancevm" {
  provider     = google.delete
  name         = "instancevm"
  machine_type = "e2-medium"
  zone         = "europe-west2-b"
}