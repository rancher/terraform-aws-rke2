variable "ssh_key_name" {
  type = string
}
variable "rke2_version" {
  type = string
}
variable "identifier" {
  type        = string
  description = "this should be a random alphanumeric string that is unique and less than 10 characters"
}
