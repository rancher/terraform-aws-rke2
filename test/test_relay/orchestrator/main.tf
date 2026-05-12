locals {
  # Instantiate variables into locals
  identifier     = var.identifier
  key_name       = var.key_name
  key            = var.key
  zone           = var.zone
  rke2_version   = var.rke2_version
  os             = var.os
  install_method = var.install_method
  cni            = var.cni
  ip_family      = var.ip_family
  runner_ip      = var.runner_ip
  age_key_path   = var.age_key_path
  secrets_path   = var.secrets_path
  deploy_path    = var.deploy_path
  data_path      = var.data_path
  template_path  = var.template_path
  home_path      = var.home_path
  root_path      = "${local.home_path}/orchestrator"

  # Find all files in template directory, creating a map with full absolute paths
  template_file_set = fileset(local.template_path, "**/*")
  template_files = {
    for f in local.template_file_set :
    f => "${local.template_path}/${f}"
  }

  # Create inputs.tfvars content (for the fixture, not the deploy module)
  inputs_content = <<-EOT
    identifier      = "${local.identifier}"
    key_name        = "${local.key_name}"
    key             = "${local.key}"
    zone            = "${local.zone}"
    rke2_version    = "${local.rke2_version}"
    os              = "${local.os}"
    install_method  = "${local.install_method}"
    cni             = "${local.cni}"
    ip_family       = "${local.ip_family}"
    runner_ip       = "${local.runner_ip}"
    data_path       = "${local.home_path}"
  EOT

  # Deploy trigger - change this to force a redeploy
  deploy_trigger = md5(join("-", [
    local.identifier,
    local.rke2_version,
    local.os,
    local.install_method,
    local.cni,
    local.ip_family,
  ]))
}

check "deploy_path" {
  assert { # if condition is false, error out with error_message
    condition     = strcontains(local.deploy_path, ":") ? false : true
    error_message = "Deploy path must not contain ':'"
  }
}

module "deploy" {
  source         = "./modules/deploy"
  deploy_path    = local.deploy_path
  data_path      = local.data_path
  root_path      = local.root_path
  module_path    = "${local.root_path}/modules/deploy"
  template_files = local.template_files
  inputs         = local.inputs_content
  deploy_trigger = local.deploy_trigger
  attempts       = 3
  interval       = 30
  timeout        = "60m"

  environment_variables = {
    AGE_KEY_PATH = local.age_key_path
    SECRETS_PATH = local.secrets_path
  }
}
