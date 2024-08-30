variable "identifier" {
  type = string
}
variable "key" {
  type = string
}
variable "key_name" {
  type = string
}
variable "fixture" {
  type        = string
  description = <<-EOT
    Directory name of the example we are testing, like 'ha', 'one', or 'splitrole'.
    This should be a directory name in the 'examples' directory.
  EOT
}

# from fixtures:
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
  default     = "sle-micro-55"
}
variable "install_method" {
  type        = string
  description = "The method used to install RKE2 on the nodes. Must be either 'tar' or 'rpm'."
  default     = "tar"
}
variable "cni" {
  type        = string
  description = "Which CNI configuration file to add."
  default     = "canal"
}
variable "ip_family" {
  type        = string
  description = "The IP family to use. Must be 'ipv4', 'ipv6', or 'dualstack'."
  default     = "ipv4"
}
variable "ingress_controller" {
  type        = string
  description = "The ingress controller to use. Must be 'nginx' or 'traefik'."
  default     = "nginx"
}
