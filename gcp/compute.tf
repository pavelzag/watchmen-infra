resource "google_compute_firewall" "default_allow_icmp" {
  name    = "default-allow-icmp"
  network = "default"

  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "default_allow_internal" {
  name    = "default-allow-internal"
  network = "default"

  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["10.128.0.0/9"]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "default_allow_rdp" {
  name    = "default-allow-rdp"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0", "10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "default_allow_ssh" {
  name    = "default-allow-ssh"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0", "10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "wm-test-allow-internal"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.128.0.0/9"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "wm-test-allow-iap-ssh"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_http_open" {
  name    = "wm-test-allow-http-open"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "attack_open_ssh" {
  name    = "wm-attack-open-ssh"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "attack_open_rdp" {
  name    = "wm-attack-open-rdp"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "attack_open_db_ports" {
  name    = "wm-attack-open-db-ports"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "tcp"
    ports    = ["3306", "5432", "27017", "6379"]
  }
}

resource "google_compute_firewall" "attack_allow_all" {
  name    = "wm-attack-allow-all-ingress"
  network = "default"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "all"
  }
}

resource "google_container_cluster" "test" {
  name     = "wm-test-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "wm-test-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.test.name
  node_count = 1

  node_config {
    preemptible     = true
    machine_type    = "e2-small"
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = google_service_account.cicd.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "google_compute_instance" "test" {
  name         = "wm-test-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  scheduling {
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
  }
}

resource "google_compute_instance" "attack_privileged_vm" {
  name         = "wm-attack-privileged-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  scheduling {
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  service_account {
    email  = google_service_account.attack_escalation_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_instance" "attack_exposed_vm" {
  name         = "wm-attack-exposed-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  scheduling {
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }
}

resource "google_compute_instance" "attack_dev_instance" {
  name         = "wm-attack-dev-instance"
  machine_type = "e2-micro"
  zone         = var.zone

  scheduling {
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }
}
