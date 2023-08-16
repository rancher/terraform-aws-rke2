output "vpc" {
  value = module.aws_access.vpc
}
output "security_group" {
  value = module.aws_access.security_group
}
output "subnet" {
  value = module.aws_access.subnet
}
output "ssh_key" {
  value = module.aws_access.ssh_key
}
output "server" {
  value = module.aws_server.id
}
output "server_public_ip" {
  value = module.aws_server.public_ip
}
