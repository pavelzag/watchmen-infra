# Minimal GKE cluster for testing the Watchmen eBPF agent DaemonSet.
#
# Deploy:
#   terraform init
#   terraform plan
#   terraform apply
#
# Get credentials after creation:
#   gcloud container clusters get-credentials watchmen-test --region us-central1
#
# Destroy:
#   terraform destroy

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {}
data "google_client_config" "current" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

locals {
  watchmen_base_url          = trimsuffix(var.watchmen_url, "/")
  watchmen_api_url           = "${local.watchmen_base_url}/api"
  watchmen_namespace         = var.watchmen_namespace
  watchmen_agent_secret_name = "watchmen-agent-secret"
  trace_test_services = {
    main = {
      name           = "watchmen-trace-main"
      service_type   = "LoadBalancer"
      downstream_csv = "http://watchmen-trace-worker-a:80/work,http://watchmen-trace-worker-b:80/work"
    }
    worker-a = {
      name           = "watchmen-trace-worker-a"
      service_type   = "ClusterIP"
      downstream_csv = ""
    }
    worker-b = {
      name           = "watchmen-trace-worker-b"
      service_type   = "ClusterIP"
      downstream_csv = "http://watchmen-trace-worker-a:80/work"
    }
  }
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "gke_test" {
  name                    = "gke-test-net"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "gke_test" {
  name          = "gke-test-subnet"
  ip_cidr_range = "10.80.0.0/16"
  network       = google_compute_network.gke_test.id
  region        = var.region

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.81.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.82.0.0/20"
  }
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  deletion_protection = false

  network    = google_compute_network.gke_test.id
  subnetwork = google_compute_subnetwork.gke_test.id

  # Regional cluster with one node per zone (3 nodes total).
  initial_node_count = 1

  # Remove the default node pool and use a separate node pool resource
  # for more control over sizing and autoscaling.
  remove_default_node_pool = true

  # Enable minimal addons.
  min_master_version = var.k8s_version
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"

  # Workload Identity for GCP service account integration.
  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }

  # Public endpoint for test convenience.
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = false
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Release channel for managed upgrades.
  release_channel {
    channel = var.release_channel
  }

  # Shielded nodes.
  enable_shielded_nodes = true

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "primary"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Start with 1 node per zone (3 nodes in a regional cluster).
  initial_node_count = var.nodes_per_zone

  autoscaling {
    min_node_count = 0
    max_node_count = var.nodes_per_zone * 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.boot_disk_gb
    disk_type    = "pd-standard"

    # Preemptible for cost savings (nodes may be reclaimed, ok for testing).
    preemptible = var.preemptible

    labels = {
      "goog-terraform-provisioned" = "true"
    }

    # OAuth scopes — minimal for testing.
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    confidential_nodes {
      enabled = false
    }
  }
}

resource "kubernetes_namespace_v1" "watchmen" {
  count = var.deploy_trace_test && var.create_watchmen_namespace ? 1 : 0

  metadata {
    name = local.watchmen_namespace

    labels = {
      name = local.watchmen_namespace
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_secret_v1" "watchmen_agent" {
  count = var.deploy_trace_test && var.create_watchmen_agent_secret ? 1 : 0

  metadata {
    name      = local.watchmen_agent_secret_name
    namespace = local.watchmen_namespace

    labels = {
      "app.kubernetes.io/name"      = "watchmen"
      "app.kubernetes.io/component" = "ebpf-agent"
    }
  }

  data = {
    agent_secret = var.watchmen_agent_secret
  }

  type = "Opaque"

  lifecycle {
    precondition {
      condition     = var.watchmen_agent_secret != ""
      error_message = "watchmen_agent_secret must be set when create_watchmen_agent_secret is true."
    }
  }

  depends_on = [kubernetes_namespace_v1.watchmen]
}

resource "kubernetes_config_map_v1" "trace_test_app" {
  count = var.deploy_trace_test ? 1 : 0

  metadata {
    name      = "watchmen-trace-go-app"
    namespace = local.watchmen_namespace

    labels = {
      "app.kubernetes.io/name"       = "watchmen-trace-go-app"
      "app.kubernetes.io/part-of"    = "watchmen"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "main.go" = <<-EOT
      package main

      import (
      	"bytes"
      	"context"
      	"crypto/sha256"
      	"encoding/json"
      	"fmt"
      	"io"
      	"log"
      	"net/http"
      	"net/url"
      	"os"
      	"strings"
      	"sync"
      	"time"
      )

      const maxBodyPreviewBytes = 8192

      type downstreamResult struct {
      	URL        string `json:"url"`
      	Method     string `json:"method"`
      	StatusCode int    `json:"statusCode,omitempty"`
      	Body       string `json:"body,omitempty"`
      	Error      string `json:"error,omitempty"`
      }

      type requestSummary struct {
      	Method        string `json:"method"`
      	Path          string `json:"path"`
      	RawQuery      string `json:"rawQuery,omitempty"`
      	ContentType   string `json:"contentType,omitempty"`
      	ContentLength int64  `json:"contentLength,omitempty"`
      	BodyBytes     int    `json:"bodyBytes"`
      	BodyPreview   string `json:"bodyPreview,omitempty"`
      	BodySHA256    string `json:"bodySha256,omitempty"`
      	From          string `json:"from,omitempty"`
      	Payload       string `json:"payload,omitempty"`
      	Probe         string `json:"probe,omitempty"`
      }

      func main() {
      	serviceName := env("SERVICE_NAME", "watchmen-trace-app")
      	listenAddr := env("LISTEN_ADDR", ":8080")
      	downstreams := splitCSV(os.Getenv("DOWNSTREAM_URLS"))
      	client := &http.Client{Timeout: 2 * time.Second}

      	mux := http.NewServeMux()
      	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
      		w.WriteHeader(http.StatusOK)
      		_, _ = w.Write([]byte("ok\n"))
      	})
      	traceHandler := handleTraceRequest(client, downstreams, serviceName)
      	for _, path := range []string{"/", "/work", "/get", "/post", "/put", "/patch", "/delete", "/head", "/options", "/trace"} {
      		mux.HandleFunc(path, traceHandler)
      	}

      	log.Printf("starting %s on %s with downstreams=%q", serviceName, listenAddr, downstreams)
      	log.Fatal(http.ListenAndServe(listenAddr, logRequests(serviceName, mux)))
      }

      func handleTraceRequest(client *http.Client, downstreams []string, serviceName string) http.HandlerFunc {
      	return func(w http.ResponseWriter, r *http.Request) {
      		w.Header().Set("Allow", "GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE")

      		requestID := r.Header.Get("X-Request-Id")
      		if requestID == "" {
      			requestID = r.Header.Get("X-Watchmen-Trace-Id")
      		}
      		if requestID == "" {
      			requestID = time.Now().UTC().Format("20060102T150405.000000000")
      		}

      		summary, body, err := summarizeRequest(r)
      		if err != nil {
      			http.Error(w, err.Error(), http.StatusBadRequest)
      			return
      		}

      		results := callDownstreams(r.Context(), client, downstreams, serviceName, requestID, r.Method, body, r.Header.Get("Content-Type"))
      		payload := map[string]any{
      			"service":     serviceName,
      			"requestId":   requestID,
      			"request":     summary,
      			"downstreams": results,
      			"time":        time.Now().UTC().Format(time.RFC3339Nano),
      		}

      		if r.Method == http.MethodOptions {
      			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE")
      			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Request-Id, X-Watchmen-Trace-Id, X-Watchmen-Trace-Source, X-Watchmen-Trace-Method")
      		}
      		if r.Method == http.MethodHead {
      			w.Header().Set("Content-Type", "application/json")
      			w.WriteHeader(http.StatusOK)
      			return
      		}

      		respondJSON(w, payload)
      	}
      }

      func summarizeRequest(r *http.Request) (requestSummary, []byte, error) {
      	var body []byte
      	if r.Body != nil {
      		defer r.Body.Close()
      		read, err := io.ReadAll(io.LimitReader(r.Body, maxBodyPreviewBytes+1))
      		if err != nil {
      			return requestSummary{}, nil, err
      		}
      		if len(read) > maxBodyPreviewBytes {
      			body = read[:maxBodyPreviewBytes]
      		} else {
      			body = read
      		}
      	}

      	sum := sha256.Sum256(body)
      	return requestSummary{
      		Method:        r.Method,
      		Path:          r.URL.Path,
      		RawQuery:      r.URL.RawQuery,
      		ContentType:   r.Header.Get("Content-Type"),
      		ContentLength: r.ContentLength,
      		BodyBytes:     len(body),
      		BodyPreview:   string(body),
      		BodySHA256:    fmt.Sprintf("%x", sum),
      		From:          r.URL.Query().Get("from"),
      		Payload:       r.URL.Query().Get("payload"),
      		Probe:         r.URL.Query().Get("probe"),
      	}, body, nil
      }

      func callDownstreams(ctx context.Context, client *http.Client, downstreams []string, serviceName, requestID, method string, body []byte, contentType string) []downstreamResult {
      	results := make([]downstreamResult, len(downstreams))
      	var wg sync.WaitGroup

      	for i, downstream := range downstreams {
      		wg.Add(1)
      		go func(i int, downstream string) {
      			defer wg.Done()

      			downstreamMethod := method
      			if downstreamMethod == http.MethodHead || downstreamMethod == http.MethodOptions || downstreamMethod == http.MethodTrace {
      				downstreamMethod = http.MethodGet
      			}

      			req, err := http.NewRequestWithContext(ctx, downstreamMethod, appendQuery(downstream, "from", serviceName), bytes.NewReader(body))
      			if err != nil {
      				results[i] = downstreamResult{URL: downstream, Method: downstreamMethod, Error: err.Error()}
      				return
      			}
      			req.Header.Set("X-Request-Id", requestID)
      			req.Header.Set("X-Watchmen-Trace-Method", method)
      			if contentType != "" && len(body) > 0 {
      				req.Header.Set("Content-Type", contentType)
      			}

      			resp, err := client.Do(req)
      			if err != nil {
      				results[i] = downstreamResult{URL: downstream, Method: downstreamMethod, Error: err.Error()}
      				return
      			}
      			defer resp.Body.Close()

      			body := make([]byte, 512)
      			n, _ := resp.Body.Read(body)
      			results[i] = downstreamResult{URL: downstream, Method: downstreamMethod, StatusCode: resp.StatusCode, Body: string(body[:n])}
      		}(i, downstream)
      	}

      	wg.Wait()
      	return results
      }

      func logRequests(serviceName string, next http.Handler) http.Handler {
      	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
      		start := time.Now()
      		next.ServeHTTP(w, r)
      		log.Printf("service=%s method=%s path=%s remote=%s duration=%s", serviceName, r.Method, r.URL.RequestURI(), r.RemoteAddr, time.Since(start))
      	})
      }

      func respondJSON(w http.ResponseWriter, payload any) {
      	w.Header().Set("Content-Type", "application/json")
      	if err := json.NewEncoder(w).Encode(payload); err != nil {
      		http.Error(w, err.Error(), http.StatusInternalServerError)
      	}
      }

      func env(key, fallback string) string {
      	value := os.Getenv(key)
      	if value == "" {
      		return fallback
      	}
      	return value
      }

      func appendQuery(rawURL, key, value string) string {
      	separator := "?"
      	if strings.Contains(rawURL, "?") {
      		separator = "&"
      	}
      	return rawURL + separator + url.QueryEscape(key) + "=" + url.QueryEscape(value)
      }

      func splitCSV(value string) []string {
      	if value == "" {
      		return nil
      	}
      	parts := strings.Split(value, ",")
      	out := make([]string, 0, len(parts))
      	for _, part := range parts {
      		part = strings.TrimSpace(part)
      		if part != "" {
      			out = append(out, part)
      		}
      	}
      	return out
      }
    EOT
  }

  depends_on = [kubernetes_namespace_v1.watchmen]
}

resource "kubernetes_deployment_v1" "trace_test" {
  for_each = var.deploy_trace_test ? local.trace_test_services : {}

  metadata {
    name      = each.value.name
    namespace = local.watchmen_namespace
    labels = {
      app                            = each.value.name
      "app.kubernetes.io/name"       = each.value.name
      "app.kubernetes.io/part-of"    = "watchmen"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          app                            = each.value.name
          "app.kubernetes.io/name"       = each.value.name
          "app.kubernetes.io/part-of"    = "watchmen"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      spec {
        init_container {
          name  = "build"
          image = var.trace_test_image
          command = [
            "go",
            "build",
            "-o",
            "/bin-app/watchmen-trace-app",
            "/app/main.go",
          ]

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "768Mi"
            }
          }

          volume_mount {
            name       = "app-source"
            mount_path = "/app"
            read_only  = true
          }
          volume_mount {
            name       = "app-bin"
            mount_path = "/bin-app"
          }
        }

        container {
          name  = "app"
          image = "alpine:3.20"
          command = [
            "/bin-app/watchmen-trace-app",
          ]

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "SERVICE_NAME"
            value = each.value.name
          }
          env {
            name  = "LISTEN_ADDR"
            value = ":8080"
          }
          env {
            name  = "DOWNSTREAM_URLS"
            value = each.value.downstream_csv
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "app-bin"
            mount_path = "/bin-app"
            read_only  = true
          }
        }

        volume {
          name = "app-source"
          config_map {
            name = kubernetes_config_map_v1.trace_test_app[0].metadata[0].name
            items {
              key  = "main.go"
              path = "main.go"
            }
          }
        }
        volume {
          name = "app-bin"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [kubernetes_config_map_v1.trace_test_app]
}

resource "kubernetes_service_v1" "trace_test" {
  for_each = var.deploy_trace_test ? local.trace_test_services : {}

  metadata {
    name      = each.value.name
    namespace = local.watchmen_namespace
    labels = {
      app                            = each.value.name
      "app.kubernetes.io/name"       = each.value.name
      "app.kubernetes.io/part-of"    = "watchmen"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "watchmen.io/role" = "trace-test"
    }
  }

  spec {
    type = each.value.service_type
    selector = {
      app = each.value.name
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "http"
    }
  }

  wait_for_load_balancer = each.value.service_type == "LoadBalancer"

  depends_on = [kubernetes_deployment_v1.trace_test]
}

resource "kubernetes_daemon_set_v1" "watchmen_ebpf_agent" {
  count = var.deploy_trace_test && var.create_watchmen_ebpf_agent ? 1 : 0

  metadata {
    name      = "watchmen-ebpf-agent"
    namespace = local.watchmen_namespace

    labels = {
      "app.kubernetes.io/name"      = "watchmen"
      "app.kubernetes.io/component" = "ebpf-agent"
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "watchmen"
        "app.kubernetes.io/component" = "ebpf-agent"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "watchmen"
          "app.kubernetes.io/component" = "ebpf-agent"
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }

        termination_grace_period_seconds = 30

        init_container {
          name  = "install"
          image = "alpine:3.20"
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              set -eu
              apk add --no-cache ca-certificates >/dev/null
              wget -qO /opt/watchmen/watchmen-ebpf-agent --timeout=30 "$WATCHMEN_AGENT_BINARY_URL"
              chmod 0755 /opt/watchmen/watchmen-ebpf-agent
            EOT
          ]

          env {
            name  = "WATCHMEN_AGENT_BINARY_URL"
            value = var.watchmen_agent_binary_url
          }
          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }
          env {
            name  = "PROJECT_ID"
            value = var.project_id
          }
          env {
            name  = "LOCATION"
            value = var.region
          }
          env {
            name  = "AGENT_VERSION"
            value = var.watchmen_agent_version
          }
          env {
            name  = "REGISTER_URL"
            value = "${local.watchmen_api_url}/agents/k8s/register"
          }
          env {
            name = "AGENT_SECRET"
            value_from {
              secret_key_ref {
                name = local.watchmen_agent_secret_name
                key  = "agent_secret"
              }
            }
          }

          volume_mount {
            name       = "opt"
            mount_path = "/opt/watchmen"
          }
        }

        container {
          name  = "agent"
          image = "alpine:3.20"
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              apk add --no-cache ca-certificates >/dev/null

              for i in 1 2 3 4 5 6; do
                wget -qO- --timeout=2 "$WATCHMEN_HEALTH_URL" >/dev/null 2>&1 && break
                echo "waiting for server..."
                sleep 10
              done

              KERNEL="$(uname -r 2>/dev/null || echo '')"
              PAYLOAD='{"clusterName":"'$CLUSTER_NAME'","projectId":"'$PROJECT_ID'","location":"'$LOCATION'","nodeName":"'$WATCHMEN_AGENT_ID'","agentSecret":"'$WATCHMEN_AGENT_SECRET'","agentVersion":"'$AGENT_VERSION'","kernelVersion":"'"$KERNEL"'"}'

              wget -qO- --timeout=5 --header="Content-Type: application/json" \
                --post-data="$PAYLOAD" \
                "$REGISTER_URL" >/dev/null || echo "registration skipped (server unreachable)"

              exec /opt/watchmen/watchmen-ebpf-agent
            EOT
          ]

          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }
          env {
            name  = "PROJECT_ID"
            value = var.project_id
          }
          env {
            name  = "LOCATION"
            value = var.region
          }
          env {
            name  = "AGENT_VERSION"
            value = var.watchmen_agent_version
          }
          env {
            name  = "REGISTER_URL"
            value = "${local.watchmen_api_url}/agents/k8s/register"
          }
          env {
            name  = "WATCHMEN_ENDPOINT"
            value = "${local.watchmen_api_url}/agents/events"
          }
          env {
            name  = "WATCHMEN_HEALTH_URL"
            value = "${local.watchmen_api_url}/health"
          }
          env {
            name = "WATCHMEN_AGENT_ID"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          env {
            name = "WATCHMEN_AGENT_SECRET"
            value_from {
              secret_key_ref {
                name = local.watchmen_agent_secret_name
                key  = "agent_secret"
              }
            }
          }
          env {
            name  = "WATCHMEN_VERBOSE"
            value = var.watchmen_agent_verbose ? "1" : "0"
          }

          security_context {
            privileged = true
          }

          volume_mount {
            name       = "opt"
            mount_path = "/opt/watchmen"
            read_only  = true
          }
          volume_mount {
            name       = "debugfs"
            mount_path = "/sys/kernel/debug"
          }
          volume_mount {
            name       = "tracefs"
            mount_path = "/sys/kernel/tracing"
          }

          resources {
            requests = {
              cpu    = "0"
              memory = "32Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "opt"
          empty_dir {}
        }
        volume {
          name = "debugfs"
          host_path {
            path = "/sys/kernel/debug"
          }
        }
        volume {
          name = "tracefs"
          host_path {
            path = "/sys/kernel/tracing"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret_v1.watchmen_agent,
    kubernetes_service_v1.trace_test,
  ]
}

resource "null_resource" "trace_test_requests" {
  count = var.deploy_trace_test && var.generate_trace_test_requests ? 1 : 0

  triggers = {
    service_ip = kubernetes_service_v1.trace_test["main"].status[0].load_balancer[0].ingress[0].ip
    requests   = var.trace_test_request_count
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      url="http://${self.triggers.service_ip}/"

      successes=0
      attempts=0
      max_attempts=$(( ${self.triggers.requests} * 18 ))

      while [ "$successes" -lt "${self.triggers.requests}" ] && [ "$attempts" -lt "$max_attempts" ]; do
        attempts=$(( attempts + 1 ))
        next=$(( successes + 1 ))

        if curl -fsS --max-time 5 "$url?watchmen_trace_test=$next" >/dev/null; then
          successes="$next"
          echo "Generated trace test request $successes/${self.triggers.requests}"
        else
          echo "Trace test endpoint not ready yet at $url; retrying..."
        fi

        sleep 1
      done

      if [ "$successes" -lt "${self.triggers.requests}" ]; then
        echo "Only generated $successes/${self.triggers.requests} requests against $url after $attempts attempts" >&2
        exit 1
      fi

      echo "Generated ${self.triggers.requests} requests against $url"
    EOT
  }

  depends_on = [
    kubernetes_service_v1.trace_test,
    kubernetes_daemon_set_v1.watchmen_ebpf_agent,
  ]
}
