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
  server_name = local.name      # this module shouldn't override the server with server_id
  server_type = var.server_type # this should be "" if the server already exists
  # image
  image_type = var.image_type # this module shouldn't override the image with image_id
  # download
  skip_download   = var.skip_download
  local_file_path = var.local_file_path
  # rke2
  rke2_version        = var.rke2_version        # even when supplying your own files, please provide the release version to install
  role                = var.role                # this should be "server" or "agent", defaults to "server"
  remote_file_path    = var.remote_file_path    # this defaults to "/home/<username>/rke2"
  retrieve_kubeconfig = var.retrieve_kubeconfig # this defaults to false
  install_method      = var.install_method      # this should be "tar" or "rpm", defaults to "tar"
  server_prep_script  = var.server_prep_script  # this should be "" if you don't want to run a script on the server before installing rke2
  start               = var.start               # if this is true the module will not start the rke2 service
  initial_config_name = var.initial_config_name
  # config
  join_token = var.join_token # this should be set, even if you are only deploying one server
  join_url   = var.join_url   # this should be null if you are deploying the first server
}

module "aws_access" {
  source              = "rancher/access/aws"
  version             = "v0.1.0"
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
  version             = "v0.1.0"
  name                = local.server_name
  owner               = local.owner
  type                = local.server_type # https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  image               = local.image_type  # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  user                = local.username
  ssh_key_name        = module.aws_access.ssh_key.tags.Name
  ssh_key             = module.aws_access.ssh_key.public_key
  subnet_name         = module.aws_access.subnet.tags.Name
  security_group_name = module.aws_access.security_group.tags.Name
}

# the idea here is to provide the least amount of config necessary to get a cluster up and running
# if a user wants to provide their own config, they can put it in the local_file_path or supply it as a string
module "config" {
  depends_on = [
    module.aws_access,
    module.aws_server,
  ]
  source            = "rancher/rke2-config/local"
  version           = "v0.1.1"
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
  version = "v0.0.3"
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
  version             = "v0.2.7"
  release             = local.rke2_version
  local_file_path     = local.local_file_path
  remote_file_path    = local.remote_file_path
  remote_workspace    = module.aws_server.workfolder
  identifier          = module.aws_server.id
  ssh_ip              = module.aws_server.public_ip
  ssh_user            = local.username
  role                = local.role
  retrieve_kubeconfig = local.retrieve_kubeconfig
  install_method      = local.install_method
  server_prep_script  = local.server_prep_script
  start               = local.start
  generated_files     = [local.initial_config_name]
}
