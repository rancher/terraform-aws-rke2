variable "key_name" {
  type        = string
  description = "The name of an ssh key that already exists in AWS of that you want to create."
}
variable "key" {
  type        = string
  description = "The content of an ssh key for server access. The key must be loaded into the running ssh agent."
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
  default     = "sle-micro-55"
}
variable "file_path" {
  type        = string
  description = "The local file path to stage or retrieve files."
  default     = ""
}
