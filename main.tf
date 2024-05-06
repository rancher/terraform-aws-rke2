locals {
  name  = var.name
  owner = var.owner

  # Project Level Variables
  vpc_use_strategy                    = var.vpc_use_strategy
  vpc_name                            = var.vpc_name
  vpc_cidr                            = var.vpc_cidr
  project_subnet_use_strategy         = var.project_subnet_use_strategy
  project_subnets                     = var.project_subnets
  project_security_group_use_strategy = var.project_security_group_use_strategy
  project_security_group_name         = var.project_security_group_name
  project_security_group_type         = var.project_security_group_type
  project_load_balancer_use_strategy  = var.project_load_balancer_use_strategy
  project_load_balancer_name          = var.project_load_balancer_name
  project_load_balancer_access_cidrs  = var.project_load_balancer_access_cidrs
  project_domain_use_strategy         = var.project_domain_use_strategy
  project_domain                      = var.project_domain
  project_domain_zone                 = var.project_domain_zone

  # Server Level Variables
  server_image_use_strategy           = var.server_image_use_strategy
  server_image                        = var.server_image
  server_image_type                   = var.server_image_type
  server_use_strategy                 = var.server_use_strategy
  server_id                           = var.server_id
  server_name                         = var.server_name
  server_type                         = var.server_type
  server_cloudinit_use_strategy       = var.server_cloudinit_use_strategy
  server_cloudinit_content            = var.server_cloudinit_content
  server_private_ip                   = var.server_private_ip
  server_indirect_access_use_strategy = var.server_indirect_access_use_strategy
  server_load_balancer_target_groups  = var.server_load_balancer_target_groups
  server_direct_access_use_strategy   = var.server_direct_access_use_strategy
  server_access_addresses             = var.server_access_addresses
  server_user                         = var.server_user
  server_add_domain                   = var.server_add_domain
  server_domain_name                  = var.server_domain_name
  server_add_eip                      = var.server_add_eip

  # download
  skip_download   = var.skip_download
  local_file_path = var.local_file_path

  # config
  join_token           = var.join_token           # this should be set, even if you are only deploying one server
  join_url             = var.join_url             # this should be null if you are deploying the first server
  extra_config_content = var.extra_config_content # put your custom config content here
  extra_config_name    = var.extra_config_name    # override the default name for this config here

  # install
  rke2_version        = var.rke2_version # even when supplying your own files, please provide the release version to install
  rpm_channel         = var.rpm_channel
  role                = var.role                # this should be "server" or "agent", defaults to "server"
  remote_file_path    = var.remote_file_path    # this defaults to "/home/<username>/rke2"
  retrieve_kubeconfig = var.retrieve_kubeconfig # this defaults to false
  install_method      = var.install_method      # this should be "tar" or "rpm", defaults to "tar"
  server_prep_script  = var.server_prep_script  # this should be "" if you don't want to run a script on the server before installing rke2
  start               = var.start               # if this is true the module will not start the rke2 service
  start_timeout       = var.start_timeout
  initial_config_name = var.initial_config_name

}

resource "null_resource" "write_extra_config" {
  triggers = {
    config_content = local.extra_config_content,
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      set -x
      install -d '${local.local_file_path}'
      cat << EOF > '${local.local_file_path}/${local.extra_config_name}'
      ${local.extra_config_content}
      EOF
      chmod 0600 '${local.local_file_path}/${local.extra_config_name}'
    EOT
  }
}

module "aws_access" {
  source                      = "rancher/access/aws"
  version                     = "v2.1.3"
  vpc_use_strategy            = local.vpc_use_strategy
  vpc_name                    = local.vpc_name
  vpc_cidr                    = local.vpc_cidr
  subnet_use_strategy         = local.subnet_use_strategy
  subnets                     = local.subnets
  security_group_use_strategy = local.security_group_use_strategy
  security_group_name         = local.security_group_name
  security_group_type         = local.security_group_type
  load_balancer_use_strategy  = local.load_balancer_use_strategy
  load_balancer_name          = local.load_balancer_name
  load_balancer_access_cidrs  = local.load_balancer_access_cidrs
  domain_use_strategy         = local.domain_use_strategy
  domain                      = local.domain
  domain_zone                 = local.domain_zone
}

module "aws_server" {
  depends_on = [
    module.aws_access
  ]
  source                       = "rancher/server/aws"
  version                      = "v1.0.0"
  image_use_strategy           = local.image_use_strategy
  image                        = local.image
  image_type                   = local.image_type
  server_use_strategy          = local.server_use_strategy
  server_id                    = local.server_id
  server_name                  = local.server_name
  server_type                  = local.server_type
  cloudinit_use_strategy       = local.cloudinit_use_strategy
  cloudinit_content            = local.cloudinit_content
  subnet_name                  = local.subnet_name
  security_group_name          = local.security_group_name
  private_ip                   = local.private_ip
  indirect_access_use_strategy = local.indirect_access_use_strategy
  load_balancer_target_groups  = local.load_balancer_target_groups
  direct_access_use_strategy   = local.direct_access_use_strategy
  server_access_addresses      = local.server_access_addresses
  server_user                  = local.server_user
  add_domain                   = local.add_domain
  domain_name                  = local.domain_name
  domain_zone                  = local.domain_zone
  add_eip                      = local.add_eip
}

# the idea here is to provide the least amount of config necessary to get a cluster up and running
# if a user wants to provide their own config, they can put it in the local_file_path or supply it as a string
module "config" {
  depends_on = [
    module.aws_access,
    module.aws_server,
  ]
  source            = "rancher/rke2-config/local"
  version           = "v0.1.3"
  token             = local.join_token
  server            = local.join_url # should not be added to the initial server
  advertise-address = module.aws_server.private_ip
  tls-san           = [module.aws_server.public_ip, module.aws_server.private_ip]
  node-external-ip  = [module.aws_server.public_ip]
  node-ip           = [module.aws_server.private_ip]
  local_file_path   = local.local_file_path
  local_file_name   = local.initial_config_name
}

module "download" {
  count   = (local.skip_download == true ? 0 : 1)
  source  = "rancher/rke2-download/github"
  version = "v0.1.1"
  release = local.rke2_version
  path    = local.local_file_path
}

module "install" {
  depends_on = [
    module.aws_access,
    module.aws_server,
    module.config,
    module.download,
  ]
  source              = "rancher/rke2-install/null"
  version             = "v1.0.2"
  release             = local.rke2_version
  rpm_channel         = local.rpm_channel
  local_file_path     = local.local_file_path
  remote_file_path    = local.remote_file_path
  remote_workspace    = module.aws_server.workfolder
  ssh_ip              = module.aws_server.public_ip
  ssh_user            = local.username
  role                = local.role
  retrieve_kubeconfig = local.retrieve_kubeconfig
  install_method      = local.install_method
  server_prep_script  = local.server_prep_script
  start               = local.start
  start_timeout       = local.start_timeout
  identifier = md5(join("-", [
    # if any of these things change, redeploy rke2
    module.aws_server.id,
    local.rke2_version,
    module.config.yaml_config,
    local.extra_config_content,
    local.server_prep_script,
    local.role,
  ]))
}
