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

resource "google_cloud_run_v2_service" "attack_leaked_aws_creds" {
  name     = "wm-attack-leaked-aws-creds"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "AWS_ACCESS_KEY_ID"
        value = "AKIAIOSFODNN7EXAMPLE"
      }

      env {
        name  = "AWS_SECRET_ACCESS_KEY"
        value = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
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

resource "google_cloud_run_v2_service" "attack_stripe_key" {
  name     = "wm-attack-stripe-key"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "STRIPE_SECRET_KEY"
        value = "sk_WATCHMEN_DEMO_NOT_A_REAL_KEY_ABCDE99"
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

resource "google_cloud_run_v2_service" "attack_github_token" {
  name     = "wm-attack-github-runner"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "GITHUB_TOKEN"
        value = "ghp_WatchmenDemoFakeTokenABCDEFGHIJKLMN01"
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

resource "google_cloud_run_v2_service" "attack_db_password_env" {
  name     = "wm-attack-db-password-env"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "DATABASE_PASSWORD"
        value = "WatchmenDemoDbPasswordSecretKey2024"
      }

      env {
        name  = "DATABASE_URL"
        value = "postgresql://admin:WatchmenDemoDbPasswordSecretKey2024@10.0.0.5:5432/prod"
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
