provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.email
    }
  }
}

locals {
  # tflint-ignore: terraform_unused_declarations
  ingress_controller = var.ingress_controller # not currently in use, TODO: add traefik functionality
  identifier         = var.identifier         # this is a random unique string that can be used to identify resources in the cloud provider
  email              = "terraform-ci@suse.com"
  example            = "one"
  project_name       = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username           = lower(substr("tf-${local.identifier}", 0, 32))
  ip_family          = var.ip_family
  runner_ip          = (var.runner_ip == "" ? chomp(data.http.myip.response_body) : var.runner_ip) # "runner" is the server running Terraform
  ssh_key            = var.key
  ssh_key_name       = var.key_name
  zone               = var.zone
  rke2_version       = var.rke2_version
  image              = var.os
  install_method     = var.install_method
  install_prep_script_file = (
    strcontains(local.image, "sles") ? "${path.root}/sles_prep.sh" :
    strcontains(local.image, "rhel") ? "${path.root}/rhel_prep.sh" :
    strcontains(local.image, "ubuntu") ? "${path.root}/ubuntu_prep.sh" :
    strcontains(local.image, "liberty") ? "${path.root}/rhel_prep.sh" :
    ""
  )
  install_prep_script = (local.install_prep_script_file == "" ? "" :
    templatefile(local.install_prep_script_file, {
      install_method = local.install_method,
      ip_family      = local.ip_family,
      image          = local.image,
    })
  )
  download     = (local.install_method == "tar" ? "download" : "skip")
  cni          = var.cni
  config_strat = (local.cni == "canal" ? "default" : "merge")
  cni_file     = (local.cni == "cilium" ? "${path.root}/cilium.yaml" : (local.cni == "calico" ? "${path.root}/calico.yaml" : ""))
  cni_config   = (local.cni_file != "" ? file(local.cni_file) : "")
  # WARNING! Local file path needs to be isolated, don't use the same path as your terraform files
  local_file_path  = (var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : var.file_path) : "${abspath(path.root)}/rke2")
  workfolder       = (strcontains(local.image, "cis") ? "/var/tmp" : "/home/${local.username}")
  k8s_target_group = substr(lower("${local.project_name}-kubectl"), 0, 32)

  # CIS images are not supported on IPv6 only deployments due to kernel modifications with how AWS IPv6 works (dhcpv6)
  # tfignore: terraform_unused_declarations
  fail_cis_ipv6 = ((local.image == "rhel-8-cis" && local.ip_family == "ipv6") ? one([local.ip_family, "cis_ipv6_incompatible"]) : false)

  # Ubuntu images do not support rpm unstall method
  # tfignore: terraform_unused_declarations
  fail_ubuntu_rpm = ((strcontains(local.image, "ubuntu") && local.install_method == "rpm") ? one([local.install_method, "ubuntu_rpm_incompatible"]) : false)
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
  source                              = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_use_strategy                = "create"
  project_vpc_use_strategy            = "create"
  project_vpc_name                    = "${local.project_name}-vpc"
  project_vpc_zones                   = [data.aws_availability_zones.available.names[0]]
  project_vpc_type                    = local.ip_family
  project_vpc_public                  = local.ip_family == "ipv6" ? false : true # ipv6 addresses assigned by AWS are always public
  project_subnet_use_strategy         = "create"
  project_subnet_names                = ["${local.project_name}-subnet"]
  project_security_group_use_strategy = "create"
  project_security_group_name         = "${local.project_name}-sg"
  project_security_group_type         = (local.install_method == "rpm" ? "egress" : "project") # rpm install requires downloading dependencies
  project_load_balancer_use_strategy  = "create"
  project_load_balancer_name          = "${local.project_name}-lb"
  project_load_balancer_access_cidrs = {
    "kubectl" = {
      port        = "6443"
      protocol    = "tcp"
      ip_family   = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs       = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
      target_name = local.k8s_target_group
    }
  }
  project_domain_use_strategy      = "create"
  project_domain                   = "${local.project_name}.${local.zone}"
  project_domain_zone              = local.zone
  project_domain_cert_use_strategy = "skip"
  server_use_strategy              = "create"
  server_name                      = "${local.project_name}-${random_pet.server.id}"
  server_type                      = "small" # smallest viable control plane node (actually t3.medium)
  server_security_group_name       = "${local.project_name}-sg"
  server_image_use_strategy        = "find"
  server_image_type                = local.image
  server_cloudinit_use_strategy    = "skip" # cloud-init not available for sle-micro
  #server_cloudinit_use_strategy = "default" # use our suggested cloud-init
  #server_cloudinit_use_strategy       = "supply"            # supply your own cloud-init in the server_cloudinit_content
  #server_cloudinit_content            = file(cloudinit.yaml) # should be raw, not base64 encoded, it will be encoded before sending it to AWS
  server_indirect_access_use_strategy = "enable"
  server_load_balancer_target_groups  = [local.k8s_target_group] # this matches the target_name from project_load_balancer_access_cidrs
  server_direct_access_use_strategy   = "ssh"                    # configure the servers for direct ssh access
  server_access_addresses = {                                    # you must include ssh access here to enable setup
    runnerSsh = {
      port      = 22 # allow access on ssh port
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
    runnerApi = {
      port      = 6443 # allow access to api
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = local.workfolder
    timeout                  = 10
  }
  server_add_domain        = false
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
  install_start_timeout    = 10
  config_use_strategy      = local.config_strat
  config_default_name      = "50-default-config.yaml"
  config_supplied_content  = local.cni_config
  config_supplied_name     = "51-cni-config.yaml"
  retrieve_kubeconfig      = true
}
