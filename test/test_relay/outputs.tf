output "runner_ip" {
  value       = module.runner.server.public_ip
  description = "The public IP address of the test relay runner."
}

output "username" {
  value       = local.username
  description = "The SSH username for connecting to the test relay runner."
}
