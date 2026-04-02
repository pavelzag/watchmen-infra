locals {
  pubsub_topics = toset([
    "wm-test-alerts",
    "wm-test-events",
    "wm-test-metrics",
    "container-analysis-notes-v1",
    "container-analysis-occurrences-v1",
    "container-analysis-notes-v1beta1",
    "container-analysis-occurrences-v1beta1",
  ])
}

resource "google_sql_database_instance" "test" {
  name             = "wm-test-sql"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_autoresize   = false
    disk_size         = 10
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time         = "03:00"
    }

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id = "wm_test_analytics"
  location   = "US"
}

resource "google_bigquery_dataset" "logs" {
  dataset_id = "wm_test_logs"
  location   = "US"
}

resource "google_bigquery_dataset" "ml_features" {
  dataset_id = "wm_test_ml_features"
  location   = "US"
}

resource "google_pubsub_topic" "topics" {
  for_each = local.pubsub_topics

  name = each.key
}

resource "google_secret_manager_secret" "api_key" {
  secret_id = "wm-test-api-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "wm-test-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "wm-test-jwt-secret"

  replication {
    auto {}
  }
}
