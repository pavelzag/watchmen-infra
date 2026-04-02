data "google_project" "current" {
  project_id = var.project_id
}

locals {
  attack_multikey_key_ids = toset([
    "e50e30798818421e2a8345762454d6146fb18283",
    "3439894292c9a2a4893a958f0578d29b1f644c11",
    "f80d998649c2ac3fe0d2476971d0b16c34d5a8ad",
    "5c2fa672b7ba5c6f86e34dbe05b16e713ab46697",
    "9df49c03ebd9cee88df9ea8b37fda6cb1091bcf3",
    "50104a6e58352e5f8e94402a062802d48ffdbe30",
    "abdc06eab86ec3d9f9238a2ef58e81d2856421e5",
    "f07b6122426cd4bf390783722279d96abb93ad3b",
    "726aa72562a38f0c651f6c8115465e16a1937ecb",
  ])

  attack_exposed_cicd_key_ids = toset([
    "698c988d677648eb63c4c11a3b5af83e0f9982fd",
    "7b85293e10467c925997086f138619ba3c78bbd7",
    "eccf7fa0f3ac1bfde9154f993d6c07ca5f11d529",
    "88633fca45515589538996dd73201d84613d0e38",
    "5e2dbda2d95e1307472a04ec1b21452675385215",
    "286fd3d85b45eccdd727f367044abc8bc69d2fc2",
  ])

  project_iam_members = {
    artifactregistry_service_agent = {
      role   = "roles/artifactregistry.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
    }
    artifactregistry_writer_github_ci = {
      role   = "roles/artifactregistry.writer"
      member = "serviceAccount:${google_service_account.github_ci.email}"
    }
    bigquery_data_viewer_reporting = {
      role   = "roles/bigquery.dataViewer"
      member = "serviceAccount:${google_service_account.reporting.email}"
    }
    bigquery_metadata_viewer_watchmen_reader = {
      role   = "roles/bigquery.metadataViewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    cloudbuild_builder_default = {
      role   = "roles/cloudbuild.builds.builder"
      member = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
    }
    cloudbuild_builder_cicd = {
      role   = "roles/cloudbuild.builds.builder"
      member = "serviceAccount:${google_service_account.cicd.email}"
    }
    cloudbuild_editor_cicd = {
      role   = "roles/cloudbuild.builds.editor"
      member = "serviceAccount:${google_service_account.cicd.email}"
    }
    cloudbuild_editor_owner = {
      role   = "roles/cloudbuild.builds.editor"
      member = "user:${var.project_owner_email}"
    }
    cloudbuild_service_agent = {
      role   = "roles/cloudbuild.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    }
    cloudsql_viewer_watchmen_reader = {
      role   = "roles/cloudsql.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    cloudtrace_user_reporting = {
      role   = "roles/cloudtrace.user"
      member = "serviceAccount:${google_service_account.reporting.email}"
    }
    compute_instance_group_manager_service_agent = {
      role   = "roles/compute.instanceGroupManagerServiceAgent"
      member = "serviceAccount:${data.google_project.current.number}@cloudservices.gserviceaccount.com"
    }
    compute_network_viewer_watchmen_reader = {
      role   = "roles/compute.networkViewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    compute_service_agent = {
      role   = "roles/compute.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
    }
    container_default_node_service_agent = {
      role   = "roles/container.defaultNodeServiceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-gkenode.iam.gserviceaccount.com"
    }
    container_service_agent = {
      role   = "roles/container.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
    }
    container_viewer_watchmen_reader = {
      role   = "roles/container.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    containeranalysis_service_agent = {
      role   = "roles/containeranalysis.ServiceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@container-analysis.iam.gserviceaccount.com"
    }
    containeranalysis_admin_watchmen_reader = {
      role   = "roles/containeranalysis.admin"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    containeranalysis_occurrences_viewer_watchmen_reader = {
      role   = "roles/containeranalysis.occurrences.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    containerregistry_service_agent = {
      role   = "roles/containerregistry.ServiceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@containerregistry.iam.gserviceaccount.com"
    }
    containerscanning_service_agent = {
      role   = "roles/containerscanning.ServiceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-containerscanning.iam.gserviceaccount.com"
    }
    # Replaced roles/editor with least-privilege roles for wm-attack-escalation-sa
    cloudbuild_viewer_attack_escalation = {
      role   = "roles/viewer"
      member = "serviceAccount:${google_service_account.attack_escalation_sa.email}"
    }
    # Replaced roles/editor with least-privilege roles for wm-attack-exposed-cicd
    cloudbuild_viewer_attack_exposed_cicd = {
      role   = "roles/viewer"
      member = "serviceAccount:${google_service_account.attack_exposed_cicd.email}"
    }
    iam_security_reviewer_reporting = {
      role   = "roles/iam.securityReviewer"
      member = "serviceAccount:${google_service_account.reporting.email}"
    }
    iam_security_reviewer_watchmen_reader = {
      role   = "roles/iam.securityReviewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    networkconnectivity_service_agent = {
      role   = "roles/networkconnectivity.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-networkconnectivity.iam.gserviceaccount.com"
    }
    # Replaced roles/owner with least-privilege roles for wm-attack-owner-sa
    viewer_attack_owner_sa = {
      role   = "roles/viewer"
      member = "serviceAccount:${google_service_account.attack_owner_sa.email}"
    }
    owner_user = {
      role   = "roles/owner"
      member = "user:${var.project_owner_email}"
    }
    pubsub_service_agent = {
      role   = "roles/pubsub.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
    }
    pubsub_viewer_watchmen_reader = {
      role   = "roles/pubsub.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    run_service_agent = {
      role   = "roles/run.serviceAgent"
      member = "serviceAccount:service-${data.google_project.current.number}@serverless-robot-prod.iam.gserviceaccount.com"
    }
    run_viewer_watchmen_reader = {
      role   = "roles/run.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    secretmanager_viewer_watchmen_reader = {
      role   = "roles/secretmanager.viewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    storage_object_viewer_watchmen_reader = {
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:${google_service_account.watchmen_reader.email}"
    }
    viewer_reporting = {
      role   = "roles/viewer"
      member = "serviceAccount:${google_service_account.reporting.email}"
    }
  }
}

resource "google_service_account" "etl" {
  account_id   = "wm-test-etl"
  display_name = "WM Test ETL Pipeline"
}

resource "google_service_account" "reporting" {
  account_id   = "wm-test-reporting"
  display_name = "WM Test Reporting"
}

resource "google_service_account" "cicd" {
  account_id   = "wm-test-cicd"
  display_name = "WM Test CI/CD Runner"
}

resource "google_service_account" "attack_escalation_sa" {
  account_id   = "wm-attack-escalation-sa"
  display_name = "WM Attack: Escalation SA (editor)"
}

resource "google_service_account" "attack_owner_sa" {
  account_id   = "wm-attack-owner-sa"
  display_name = "WM Attack: Owner SA (full takeover)"
}

resource "google_service_account" "attack_multikey_sa" {
  account_id   = "wm-attack-multikey-sa"
  display_name = "WM Attack: SA with Multiple Keys"
}

resource "google_service_account" "attack_exposed_cicd" {
  account_id   = "wm-attack-exposed-cicd"
  display_name = "WM Attack: CI/CD SA (editor + multi-key)"
}

resource "google_service_account" "github_ci" {
  account_id = "github-ci"
}

resource "google_service_account" "watchmen_reader" {
  account_id   = "watchmen-reader"
  display_name = "Watchmen Reader"
}

resource "google_project_iam_member" "bindings" {
  for_each = local.project_iam_members

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

resource "google_service_account_key" "attack_multikey" {
  for_each = local.attack_multikey_key_ids

  service_account_id = google_service_account.attack_multikey_sa.name
}

resource "google_service_account_key" "attack_exposed_cicd" {
  for_each = local.attack_exposed_cicd_key_ids

  service_account_id = google_service_account.attack_exposed_cicd.name
}