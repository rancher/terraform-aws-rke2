output "kubeconfig" {
  value       = local_file.kubeconfig.content
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}

output "api" {
  value       = "https://${module.runner.server.public_ip}:6443"
  description = "API endpoint for the cluster."
  sensitive   = true
}
