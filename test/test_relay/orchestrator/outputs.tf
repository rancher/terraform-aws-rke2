output "kubeconfig" {
  value       = module.deploy.output.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "server_ip" {
  value       = module.deploy.output.server_ip
  description = "IP address of the cluster's initial node."
  sensitive   = true
}
output "username" {
  value       = module.deploy.output.username
  description = "Username for the cluster."
  sensitive   = true
}
output "api" {
  value       = module.deploy.output.api
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
