variable "ssh_key_name" {
  type        = string
  description = <<-EOT
    This is the name of the ssh keypair in AWS.
    The keypair needs to have a tag with 'Name' and a value equal to this.
    You should have the private key already added to your ssh-agent.
  EOT
}
variable "rke2_version" {
  type        = string
  description = <<-EOT
    This is an RKE2 release tag.
  EOT
}
variable "identifier" {
  type        = string
  description = <<-EOT
    this should be a random alphanumeric string that is unique and less than 10 characters
  EOT
}
