output "kubeconfig" {
  value       = module.this.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "api" {
  value       = "${local.project_name}.${local.zone}"
  description = "Address to use to connect to the cluster's API service."
}
output "server_ip" {
  value       = trimsuffix(trimprefix(trimsuffix(trimprefix(yamldecode(module.this.server_kubeconfig).clusters[0].cluster.server, "https://"), ":6443"), "["), "]")
  description = "IP address of the cluster's initial node."
  sensitive   = true
}
output "load_balancer" {
  value = module.this.project_load_balancer
}
output "vpc" {
  value = module.this.project_vpc
}
