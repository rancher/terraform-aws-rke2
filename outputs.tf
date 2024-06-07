output "kubeconfig" {
  value       = (local.retrieve_kubeconfig ? module.install[0].kubeconfig : "")
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "join_url" {
  value       = (local.config_join_url != "" ? local.config_join_url : "https://${module.server[0].server.private_ip}:9345")
  description = <<-EOT
    The URL to join this cluster.
  EOT
}
output "join_token" {
  value       = local.join_token
  description = <<-EOT
    The token for a server to join this cluster.
  EOT
  sensitive   = true
}
# output "agent_join_token" {
#   value       = local.agent_join_token
#   description = <<-EOT
#     The token for an agent to join this cluster.
#   EOT
#   sensitive   = true
# }
