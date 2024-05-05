locals {
  name  = var.name
  owner = var.owner
  # vpc
  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr # this should be "" if the vpc already exists
  # subnet
  subnet_name       = var.subnet_name
  subnet_cidr       = var.subnet_cidr       # this should be "" if the subnet already exists
  availability_zone = var.availability_zone # this should be "" if the subnet already exists, when generating a subnet if this is "" then the subnet will be created in the default zone for the region
  # security group
  security_group_name = var.security_group_name
  security_group_type = var.security_group_type # this should be "" if the security group already exists
  security_group_ip   = var.security_group_ip   # this can be "", but it will cause the module to attempt to look up the current public ip
  # ssh access
  username        = var.ssh_username
  ssh_key_name    = var.ssh_key_name
  ssh_key_content = var.ssh_key_content
  # server
  server_name              = local.name      # this module shouldn't override the server with server_id
  server_type              = var.server_type # this should be "" if the server already exists
  server_cloudinit_timeout = var.server_cloudinit_timeout
  server_cloudinit_script  = var.server_cloudinit_script
  # image
  image_type = var.image_type # this module shouldn't override the image with image_id
  # download
  skip_download   = var.skip_download
  local_file_path = var.local_file_path
  # rke2
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
  # config
  join_token           = var.join_token           # this should be set, even if you are only deploying one server
  join_url             = var.join_url             # this should be null if you are deploying the first server
  extra_config_content = var.extra_config_content # put your custom config content here
  extra_config_name    = var.extra_config_name    # override the default name for this config here
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
  source              = "rancher/access/aws"
  version             = "2.1.3"
  owner               = local.owner
  vpc_name            = local.vpc_name
  vpc_cidr            = local.vpc_cidr
  subnet_name         = local.subnet_name
  subnet_cidr         = local.subnet_cidr
  availability_zone   = local.availability_zone
  security_group_name = local.security_group_name
  security_group_type = local.security_group_type # https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  security_group_ip   = local.security_group_ip
  ssh_key_name        = local.ssh_key_name
  public_ssh_key      = local.ssh_key_content
}

module "aws_server" {
  depends_on = [
    module.aws_access
  ]
  source              = "rancher/server/aws"
  version             = "v0.4.1"
  name                = local.server_name
  owner               = local.owner
  type                = local.server_type # https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  image               = local.image_type  # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  user                = local.username
  ssh_key_name        = local.ssh_key_name # derive this from local values rather than the module to avoid dependency issues
  ssh_key             = module.aws_access.ssh_key.public_key
  subnet_name         = local.subnet_name         # derive this from local values rather than the module to avoid dependency issues
  security_group_name = local.security_group_name # derive this from local values rather than the module to avoid dependency issues
  cloudinit_script    = local.server_cloudinit_script
  cloudinit_timeout   = local.server_cloudinit_timeout
  add_public_ip       = true # we need a public ip to login and install rke2, if looking for something to just boot a preconfigured image, try using the server mod directly
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
