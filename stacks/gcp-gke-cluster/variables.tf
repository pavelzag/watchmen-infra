variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "watchmen-test-488807"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "watchmen-test"
}

variable "k8s_version" {
  description = "Kubernetes version (prefix, e.g. 1.34)"
  type        = string
  default     = "1.34"
}

variable "release_channel" {
  description = "GKE release channel (UNSPECIFIED, RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-medium"
}

variable "nodes_per_zone" {
  description = "Number of nodes per zone"
  type        = number
  default     = 1
}

variable "boot_disk_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "watchmen_url" {
  description = "Watchmen server base URL (e.g. https://watchmen.example.com)"
  type        = string
}

variable "deploy_trace_test" {
  description = "Deploy a public LoadBalancer test service and the Watchmen eBPF agent into the GKE cluster."
  type        = bool
  default     = false
}

variable "watchmen_namespace" {
  description = "Kubernetes namespace for the Watchmen test workload and eBPF agent."
  type        = string
  default     = "watchmen"
}

variable "create_watchmen_namespace" {
  description = "Create the Watchmen namespace. Set to false when the namespace already exists."
  type        = bool
  default     = false
}

variable "watchmen_agent_secret" {
  description = "Shared secret used by the eBPF agent to authenticate with the Watchmen API."
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_watchmen_agent_secret" {
  description = "Create watchmen-agent-secret. Set to false when the secret already exists in watchmen_namespace."
  type        = bool
  default     = false
}

variable "watchmen_agent_binary_url" {
  description = "Download URL for the Linux amd64 Watchmen eBPF agent binary."
  type        = string
  default     = "https://github.com/pavelzag/watchmen/releases/download/agent-v0.3.18/watchmen-ebpf-agent-linux-amd64"
}

variable "watchmen_agent_version" {
  description = "Agent version string reported during Watchmen registration."
  type        = string
  default     = "0.3.18"
}

variable "watchmen_agent_verbose" {
  description = "Enable verbose eBPF agent logging."
  type        = bool
  default     = true
}

variable "create_watchmen_ebpf_agent" {
  description = "Create watchmen-ebpf-agent DaemonSet. Set to false when the DaemonSet already exists in watchmen_namespace."
  type        = bool
  default     = false
}

variable "trace_test_image" {
  description = "Go container image used by the init container to build the ConfigMap-backed trace test services."
  type        = string
  default     = "golang:1.24-alpine"
}

variable "generate_trace_test_requests" {
  description = "Generate HTTP requests against the LoadBalancer after Terraform creates it."
  type        = bool
  default     = true
}

variable "trace_test_request_count" {
  description = "Number of HTTP requests Terraform should send to the LoadBalancer for Trace UI verification."
  type        = number
  default     = 10
}

variable "preemptible" {
  description = "Use preemptible nodes (cheaper, may be reclaimed)"
  type        = bool
  default     = true
}
