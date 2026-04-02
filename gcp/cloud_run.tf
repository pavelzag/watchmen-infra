resource "google_cloud_run_v2_service" "hello" {
  name     = "wm-test-hello"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_cloud_run_v2_service" "api" {
  name     = "wm-test-api"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_secret_manager_secret" "aws_access_key_id" {
  secret_id = "aws-access-key-id"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "aws_access_key_id" {
  secret      = google_secret_manager_secret.aws_access_key_id.id
  secret_data = "AKIAIOSFODNN7EXAMPLE"
}

resource "google_secret_manager_secret" "aws_secret_access_key" {
  secret_id = "aws-secret-access-key"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "aws_secret_access_key" {
  secret      = google_secret_manager_secret.aws_secret_access_key.id
  secret_data = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

resource "google_cloud_run_v2_service" "attack_leaked_aws_creds" {
  name     = "wm-attack-leaked-aws-creds"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "AWS_ACCESS_KEY_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.aws_access_key_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "AWS_SECRET_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.aws_secret_access_key.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_secret_manager_secret" "stripe_secret_key" {
  secret_id = "stripe-secret-key"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "stripe_secret_key" {
  secret      = google_secret_manager_secret.stripe_secret_key.id
  secret_data = "sk_WATCHMEN_DEMO_NOT_A_REAL_KEY_ABCDE99"
}

resource "google_cloud_run_v2_service" "attack_stripe_key" {
  name     = "wm-attack-stripe-key"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "STRIPE_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.stripe_secret_key.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_secret_manager_secret" "github_token" {
  secret_id = "github-token"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_token" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = "ghp_WatchmenDemoFakeTokenABCDEFGHIJKLMN01"
}

resource "google_cloud_run_v2_service" "attack_github_token" {
  name     = "wm-attack-github-runner"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "GITHUB_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_token.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_secret_manager_secret" "database_password" {
  secret_id = "database-password"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_password" {
  secret      = google_secret_manager_secret.database_password.id
  secret_data = "WatchmenDemoDbPasswordSecretKey2024"
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "database-url"
  project   = "watchmen-test-488807"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://admin:WatchmenDemoDbPasswordSecretKey2024@10.0.0.5:5432/prod"
}

resource "google_cloud_run_v2_service" "attack_db_password_env" {
  name     = "wm-attack-db-password-env"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "DATABASE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_cloud_run_v2_service" "attack_public_internal_api" {
  name     = "wm-attack-public-internal-api"
  location = var.region

  template {
    service_account = google_service_account.attack_escalation_sa.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

resource "google_cloud_run_v2_service" "attack_public_api" {
  name     = "wm-attack-public-api"
  location = var.region

  template {
    service_account = google_service_account.attack_owner_sa.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}