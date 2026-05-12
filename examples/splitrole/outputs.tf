# the initial node doesn't include a project so its "kubeconfig" output will be blank
# this means we need to generate a cluster level kubeconfig with our knowledge of the project
output "kubeconfig" {
  value = (
    # Replace the server IP with the domain name
    replace(
      module.deploy_initial_node.output.server_kubeconfig,
      # when replacing the ipv6 server ip, also replace the brackets
      (local.ip_family == "ipv6" ? "[${module.deploy_initial_node.output.server_public_ip}]" : module.deploy_initial_node.output.server_public_ip),
      "${local.project_domain}.${local.zone}"
    )
  )
  description = <<-EOT
    The kubeconfig for the cluster.
    This replaces the server's public ip with the project's fqdn.
  EOT
  sensitive   = true
}

output "server_ip" {
  value       = module.deploy_initial_node.output.server_public_ip
  description = "IP address of the cluster's initial node."
  sensitive   = true
}
output "username" {
  value       = local.username
  description = "Username for the cluster."
  sensitive   = true
}
output "api" {
  value       = try(yamldecode(module.deploy_initial_node.output.kubeconfig).clusters[0].cluster.server, "https://${local.project_domain}.${local.zone}:6443")
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
