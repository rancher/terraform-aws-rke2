provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.email
    }
  }
}

locals {
  identifier         = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  email              = "terraform-ci@suse.com"
  example            = "one"
  project_name       = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username           = "tf-${local.identifier}"
  ip_family          = var.ip_family          # not currently in use, TODO: add dualstack functionality
  ingress_controller = var.ingress_controller # not currently in use, TODO: add traefik functionality
  vpc_cidr           = "10.0.0.0/16"
  subnet_cidr        = cidrsubnet(local.vpc_cidr, 1, 0)    # get the first subnet when dividing the vpc_cidr into 2 /17 subnets
  server_ip          = cidrhost(local.subnet_cidr, 5)      # AWS reserves the first 4 usable addresses
  runner_ip          = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  ssh_key            = var.key
  ssh_key_name       = var.key_name
  zone               = var.zone
  rke2_version       = var.rke2_version
  image              = var.os
  install_method     = var.install_method
  install_prep_script = (
    strcontains(local.image, "sles-15") ? file("${path.root}/suse_prep.sh") :
    (strcontains(local.image, "ubuntu") ? file("${path.root}/ubuntu_prep.sh") :
      (strcontains(local.image, "rhel") ? file("${path.root}/rhel_prep.sh") :
  "")))
  download     = (local.install_method == "tar" ? "download" : "skip")
  cni          = var.cni
  config_strat = (local.cni == "canal" ? "default" : "merge")
  cni_file     = (local.cni == "cilium" ? "${path.root}/cilium.yaml" : (local.cni == "calico" ? "${path.root}/calico.yaml" : ""))
  cni_config   = (local.cni_file != "" ? file(local.cni_file) : "")
  # WARNING! Local file path needs to be isolated, don't use the same path as your terraform files
  local_file_path = (var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : var.file_path) : "${abspath(path.root)}/rke2")
  workfolder      = (strcontains(local.image, "cis") ? "/var/tmp" : "/home/${local.username}")
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
  project_security_group_type         = (local.install_method == "rpm" ? "egress" : "project") # rpm install requires downloading dependencies
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
    user_workfolder          = local.workfolder
    timeout                  = 5
  }
  server_add_domain        = true
  server_domain_name       = "${local.project_name}-${random_pet.server.id}.${local.zone}"
  server_domain_zone       = local.zone
  server_add_eip           = false
  install_use_strategy     = local.install_method
  local_file_use_strategy  = local.download
  local_file_path          = local.local_file_path
  install_rke2_version     = local.rke2_version
  install_rpm_channel      = "stable"
  install_remote_file_path = "${local.workfolder}/rke2"
  install_role             = "server"
  install_start            = true
  install_prep_script      = local.install_prep_script
  install_start_timeout    = 5
  config_use_strategy      = local.config_strat
  config_default_name      = "50-default-config.yaml"
  config_supplied_content  = local.cni_config
  config_supplied_name     = "51-cni-config.yaml"
  retrieve_kubeconfig      = true
}
