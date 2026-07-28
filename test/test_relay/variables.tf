variable "identifier" {
  type        = string
  description = "A random alphanumeric string that is unique and less than 10 characters."
}

variable "key" {
  type        = string
  description = "The content of a public ssh key for server access."
}

variable "key_name" {
  type        = string
  description = "The name of an ssh key that already exists in AWS or that you want to create."
}

variable "relay_os" {
  type        = string
  description = "The OS image to use for the test relay runner. Must be a SLES or Ubuntu based image (e.g. sles-16, ubuntu-24)."
  default     = "ubuntu-24"
  validation {
    condition     = can(regex("^(sles-|ubuntu-)", var.relay_os))
    error_message = "The relay_os must be a SLES or Ubuntu operating system (e.g. sles-15, sles-16, ubuntu-22, ubuntu-24)."
  }
}

variable "repo_archive_path" {
  type        = string
  description = "The path to the packaged repository tar.gz archive on the local machine."
}
