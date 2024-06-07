provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.email
    }
  }
}

locals {
  identifier      = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  email           = "terraform-ci@suse.com"
  example         = "simple"
  project_name    = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username        = lower(substr("tf-${local.identifier}", 0, 32))
  runner_ip       = chomp(data.http.myip.response_body)
  ssh_key         = var.key
  ssh_key_name    = var.key_name
  zone            = var.zone
  rke2_version    = var.rke2_version
  local_file_path = var.file_path
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "this" {
  source               = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_name         = local.project_name
  project_admin_cidrs  = ["${local.runner_ip}/32"]
  project_domain       = "${local.project_name}.${local.zone}"
  project_access_cidrs = ["${local.runner_ip}}/32"] # allow access to the project from these cidrs
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = "/home/${local.username}"
    timeout                  = 5
  }
  local_file_path      = local.local_file_path
  install_rke2_version = local.rke2_version
}
