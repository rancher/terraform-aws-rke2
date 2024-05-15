provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.email
    }
  }
}

locals {
  identifier   = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  email        = "terraform-ci@suse.com"
  example      = "allinone"
  project_name = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username     = "tf-${local.identifier}"
  vpc_cidr     = "10.0.255.0/24"   # gives 256 usable addresses from .1 to .254, but AWS reserves .1 to .4 and .255, leaving .5 to .254
  subnet_cidr  = "10.0.255.224/28" # gives 18 usable addresses from .225 to .238, but AWS reserves .225 to .228 and .238, leaving .229 to .237
  server_ip    = "10.0.255.229"
  runner_ip    = chomp(data.http.myip.response_body)
  ssh_key      = var.key
  ssh_key_name = var.key_name
  zone         = var.zone
  rke2_version = var.rke2_version
  image        = var.os
  # WARNING! Local file path needs to be isolated, don't use the same path as your terraform files
  local_file_path = (var.file_path != "" ? var.file_path : "${abspath(path.root)}/rke2")
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

resource "random_pet" "server" {
  keepers = {
    identifier = local.identifier
  }
  length = 1
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "this" {
  source                      = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_use_strategy        = "create"
  project_vpc_use_strategy    = "create"
  project_vpc_name            = "${local.project_name}-vpc"
  project_vpc_cidr            = local.vpc_cidr
  project_subnet_use_strategy = "create"
  project_subnets = {
    "${local.project_name}-sn" = {
      cidr              = local.subnet_cidr
      availability_zone = data.aws_availability_zones.available.names[0]
      public            = true
    }
  }
  project_security_group_use_strategy = "create"
  project_security_group_name         = "${local.project_name}-sg"
  project_security_group_type         = "project"
  project_load_balancer_use_strategy  = "create"
  project_load_balancer_name          = "${local.project_name}-lb"
  project_load_balancer_access_cidrs = {
    ping = {
      port     = "443"
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to ping service from this CIDR only
    }
  }
  project_domain_use_strategy   = "create"
  project_domain                = "${local.project_name}.${local.zone}"
  server_use_strategy           = "create"
  server_name                   = "${local.project_name}-${random_pet.server.id}"
  server_type                   = "small" # smallest viable control plane node (actually t3.medium)
  server_subnet_name            = "${local.project_name}-sn"
  server_security_group_name    = "${local.project_name}-sg"
  server_private_ip             = local.server_ip
  server_image_use_strategy     = "find"
  server_image_type             = local.image
  server_cloudinit_use_strategy = "skip" # cloud-init not available for sle-micro
  #server_cloudinit_use_strategy = "default" # use our suggested cloud-init
  #server_cloudinit_use_strategy = "supply" # supply your own cloud-init in the server_cloudinit_content
  #server_cloudinit_content = file(coudinit.yaml) # should be raw, not base64 encoded, it will be encoded before sending it to AWS
  server_indirect_access_use_strategy = "enable"
  server_load_balancer_target_groups  = ["${local.project_name}-lb-ping"] # this will always be <load balancer name>-<load balancer access cidrs key>
  server_direct_access_use_strategy   = "ssh"                             # configure the servers for direct ssh access
  server_access_addresses = {                                             # you must include ssh access here to enable setup
    runnerSsh = {
      port     = 22 # allow access on ssh port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runnerKubectl = {
      port     = 6443 # allow access on this port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = "/home/${local.username}"
    timeout                  = 5
  }
  server_add_domain         = true
  server_domain_name        = "${local.project_name}-${random_pet.server.id}.${local.zone}"
  server_domain_zone        = local.zone
  server_add_eip            = false
  install_use_strategy      = "tar"
  local_file_use_strategy   = "download"
  local_file_path           = local.local_file_path
  install_rke2_version      = local.rke2_version
  install_rpm_channel       = "stable"
  install_remote_file_path  = "/home/${local.username}/rke2"
  install_role              = "server"
  install_start             = true
  install_start_prep_script = file("${path.root}/prep.sh")
  install_start_timeout     = 5
  config_use_strategy       = "default"
  config_default_name       = "50-default-config.yaml"
  retrieve_kubeconfig       = true
}
data "local_sensitive_file" "kubeconfig" {
  depends_on = [
    module.this,
  ]
  filename = "${local.local_file_path}/kubeconfig"
}
