output "kubeconfig" {
  value       = module.initial.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}

