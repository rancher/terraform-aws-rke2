variable "inputs" {
  type        = string
  description = <<-EOT
    Contents of an inputs.tfvars file to save in the deployment path.
  EOT
}
variable "template_files" {
  type        = map(any)
  description = <<-EOT
    Map of relative path => absolute path for files that will be copied to the deploy path.
    The key is the relative path (used in deploy_path), the value is the absolute source path.
    Example: { "modules/deploy/main.tf" => "/home/user/fixture/modules/deploy/main.tf" }
  EOT
}
variable "deploy_path" {
  type        = string
  description = <<-EOT
    Path to preform deployment in, this will be Terraform's working directory.
  EOT
  validation {
    condition = (
      contains(["one", "ha", "prod", "splitrole"], basename(var.deploy_path))
    )
    error_message = "The path's basename must be one of 'one', 'ha', 'prod', or 'splitrole'."
  }
}
variable "root_path" {
  type        = string
  description = "The absolute file path where this module is implemented, most likely the directory terraform is run from."
}
variable "module_path" {
  type        = string
  description = <<-EOT
    The absolute file path where the imported module is located, most likely in the .terraform directory.
    If left empty this will default to path.module.
  EOT
  default     = ""
}
variable "data_path" {
  type        = string
  description = <<-EOT
    Should match your TF_DATA_DIR environment variable.
    This directory is used to stage all of the various files for your implementation.
    This should be a full path, not relative.
  EOT
}
variable "environment_variables" {
  type        = map(any)
  description = <<-EOT
    Map of environment variables to set before running Terraform.
    Key is the name and Value is the value of the variable.
    We export this before running Terraform, eg. "export KEY_1=VARIABLE_1;export KEY_2=VARIABLE_2".
  EOT
}
variable "attempts" {
  type        = number
  description = <<-EOT
    Number of attempts to deploy module.
    Each time Terraform apply is run we check for a successful exit code,
     if the exit code !=0 then we try again, up to the value set in this argument.
  EOT
  default     = 3
}
variable "interval" {
  type        = number
  description = <<-EOT
    A number of seconds to sleep between Terraform apply or destroy attempts.
  EOT
  default     = 30
}
variable "timeout" {
  type        = string
  description = <<-EOT
    A (linux coreutils) timeout DURATION string.
    This will be used to kill the Terraform run in case there is an endless loop.
    If this DURATION is reached a single TERM will be sent, then KILL 1 minute later.
  EOT
  default     = "45m"
}
variable "init" {
  type        = bool
  description = <<-EOT
    Set to false to prevent running Terraform init.
    This is helpful when testing a local bin version of the provider.
  EOT
  default     = true
}
variable "skip_destroy" {
  type        = bool
  description = <<-EOT
    Set to true to ignore calls to destroy the deployed substate.
    State and deploy path will still exist, this essentially divorces the parent from the child.
    This only effects specifically calls to destroy the deploy module, not taint or recreate.
    Be careful as this can leave objects in your API unmanaged by IAC.
  EOT
  default     = false
}
variable "deploy_trigger" {
  type        = string
  description = <<-EOT
    An arbitrary string which describes the deployment itself (not what it is deploying).
    When this string changes the module will update the deployment files from the other inputs given.
    This means that arbitrary changes to this module's inputs don't cause the deployment to trigger,
     the deployment will only trigger when this string changes.
  EOT
}
