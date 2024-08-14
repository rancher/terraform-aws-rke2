output "kubeconfig" {
  value       = module.this.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "server_ip" {
  value       = trimsuffix(trimprefix(trimsuffix(trimprefix(yamldecode(module.this.server_kubeconfig).clusters[0].cluster.server, "https://"), ":6443"), "["), "]")
  description = "IP address of the cluster's initial node."
  sensitive   = true
}
output "username" {
  value     = local.username
  sensitive = true
}
output "api" {
  value       = yamldecode(module.this.kubeconfig).clusters[0].cluster.server
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
