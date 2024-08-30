output "kubeconfig" {
  value       = local_file.kubeconfig.content
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
