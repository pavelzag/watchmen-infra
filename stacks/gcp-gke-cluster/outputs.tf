output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "endpoint" {
  description = "Cluster master API endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "k8s_version" {
  description = "Kubernetes version"
  value       = google_container_cluster.primary.master_version
}

output "node_count" {
  description = "Total node count across all zones"
  value       = google_container_node_pool.primary_nodes.node_count
}

output "get_credentials" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "deploy_agent" {
  description = "Command to deploy the Watchmen eBPF agent"
  value       = "kubectl apply -f ${var.watchmen_url}/api/agents/k8s/manifest?cluster=${var.cluster_name}&project=${var.project_id}"
}

output "trace_test_load_balancer_ip" {
  description = "External IP for the Terraform-managed watchmen-trace-main LoadBalancer."
  value       = var.deploy_trace_test ? try(kubernetes_service_v1.trace_test["main"].status[0].load_balancer[0].ingress[0].ip, null) : null
}

output "trace_test_url" {
  description = "HTTP URL for the Terraform-managed public trace test service."
  value       = var.deploy_trace_test ? try("http://${kubernetes_service_v1.trace_test["main"].status[0].load_balancer[0].ingress[0].ip}/", null) : null
}

output "generate_trace_test_requests" {
  description = "Command to generate additional trace test requests after apply."
  value       = var.deploy_trace_test ? try("for i in $(seq 1 10); do curl -fsS 'http://${kubernetes_service_v1.trace_test["main"].status[0].load_balancer[0].ingress[0].ip}/?manual_trace_test='$i >/dev/null; sleep 1; done", null) : null
}

output "trace_ui_check" {
  description = "Open this Watchmen Trace UI URL and look for watchmen-trace-main, watchmen-trace-worker-a, and watchmen-trace-worker-b traffic."
  value       = var.deploy_trace_test ? "${trimsuffix(var.watchmen_url, "/")}/trace" : null
}
