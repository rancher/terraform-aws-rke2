output "kubeconfig" {
  value       = module.this.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
