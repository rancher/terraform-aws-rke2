output "kubeconfig" {
  value     = module.InitialServer.kubeconfig
  sensitive = true
}
output "ssh" {
  value = merge(
    { "${local.names[0]}" = "${local.username}@${module.InitialServer.server_public_ip}" },
    { for i in range(1, local.server_count) : local.names[i] => "${local.username}@${module.Servers[local.names[i]].server_public_ip}" },
    { for i in range(local.server_count, (local.server_count + local.agent_count)) : local.names[i] => "${local.username}@${module.Agents[local.names[i]].server_public_ip}" }
  )
}