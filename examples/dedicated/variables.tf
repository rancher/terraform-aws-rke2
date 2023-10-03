variable "ssh_key_name" {
  type        = string
  description = <<-EOT
    This is the name of the ssh keypair in AWS.
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
  description = "this should be a random alphanumeric string that is unique and less than 10 characters"
}
variable "extra_config_path" {
  type        = string
  description = <<-EOT
    This is the path to a yaml config that will be added to the node's config.yaml.d directory.
    The file will be named "51-extra-config.yaml".
    The file will be added to the local_file_path directory.
  EOT
  default     = ""
}
variable "server_prep_script" {
  type        = string
  description = <<-EOT
    The path to a script that will be run on the server before the install script is run.
    This will be copied to the remote server and run with sudo.
  EOT
  default     = "prep.sh"
}