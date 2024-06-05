output "kubeconfig" {
  value       = (local.retrieve_kubeconfig ? module.install[0].kubeconfig : "")
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "join_url" {
  value = (local.config_join_url != "" ? local.config_join_url :
    (
      local.server_domain_name != "" ? "https://${local.server_domain_name}:9345" :
      "https://${module.server[0].server.private_ip}:9345"
    )
  )
  description = <<-EOT
    The URL to join this cluster.
  EOT
}
output "join_token" {
  value       = local.join_token
  description = <<-EOT
    The token to join this cluster.
  EOT
  sensitive   = true
}
