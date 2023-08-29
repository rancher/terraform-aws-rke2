output "vpc" {
  value       = module.aws_access.vpc
  description = <<-EOT
    The VPC object from AWS.
  EOT
}
output "security_group" {
  value       = module.aws_access.security_group
  description = <<-EOT
    The security group object from AWS.
  EOT
}
output "subnet" {
  value       = module.aws_access.subnet
  description = <<-EOT
    The CIDR block of the subnet.
  EOT
}
output "ssh_key" {
  value       = module.aws_access.ssh_key
  description = <<-EOT
    The SSH key object from AWS.
  EOT
}
output "server" {
  value       = module.aws_server.server
  description = <<-EOT
    The server object from AWS.
  EOT
}
output "server_public_ip" {
  value       = module.aws_server.public_ip
  description = <<-EOT
    The public IP of the server.
  EOT
}
output "join_url" {
  value       = "https://${module.aws_server.private_ip}:9345"
  description = <<-EOT
    The join URL for the server.
  EOT
}
