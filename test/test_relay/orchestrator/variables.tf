variable "key_name" {
  type        = string
  description = "The name of an ssh key that already exists in AWS of that you want to create."
}
variable "key" {
  type        = string
  description = "The content of a public ssh key for server access. The key must be loaded into the running ssh agent."
}
variable "identifier" {
  type        = string
  description = "A random alphanumeric string that is unique and less than 10 characters."
}
variable "zone" {
  type        = string
  description = "The dns zone to add domains under, must already exist in AWS Route53."
}
variable "rke2_version" {
  type        = string
  description = "The rke2 version to install."
}
variable "os" {
  type        = string
  description = "The operating system to deploy."
}
variable "install_method" {
  type        = string
  description = "The method used to install RKE2 on the nodes. Must be either 'tar' or 'rpm'."
}
variable "cni" {
  type        = string
  description = "Which CNI configuration file to add."
}
variable "ip_family" {
  type        = string
  description = "The IP family to use. Must be 'ipv4', 'ipv6', or 'dualstack'."
}
variable "runner_ip" {
  type        = string
  description = "The runner may have multiple IP addresses, use this to specify which one to use."
  # by default we will find the ip address using "https://ipinfo.io/ip"
}
variable "age_key_path" {
  type        = string
  description = "Path to the age encryption key file."
}
variable "secrets_path" {
  type        = string
  description = "Path to the encrypted secrets file."
}
variable "template_path" {
  type        = string
  description = "Path to the fixture templates directory."
}
variable "deploy_path" {
  type        = string
  description = "Path where the fixture should be instantiated/deployed."
  validation {
    condition = (
      contains(["one", "ha", "prod", "splitrole"], basename(var.deploy_path))
    )
    error_message = "The path's basename must be one of 'one', 'ha', 'prod', or 'splitrole'."
  }
}
variable "data_path" {
  type        = string
  description = "Path where the fixture's data should be instantiated/deployed."
}
variable "home_path" {
  type        = string
  description = "User's home path on the remote server."
}
