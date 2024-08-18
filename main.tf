locals {
  # Feature: Project
  project_use_strategy     = var.project_use_strategy
  project_name             = var.project_name
  project_admin_cidrs      = var.project_admin_cidrs
  project_mod              = (local.project_use_strategy == "skip" ? 0 : 1)
  project_vpc_use_strategy = var.project_vpc_use_strategy
  project_vpc_name         = (var.project_vpc_name != "" ? var.project_vpc_name : (local.project_name != "" ? "${local.project_name}-vpc" : ""))
  project_vpc_cidr         = var.project_vpc_cidr

  # Feature: project - subnets
  project_subnet_use_strategy = var.project_subnet_use_strategy
  project_subnets             = var.project_subnets

  # Feature: project - security groups
  project_security_group_use_strategy = var.project_security_group_use_strategy
  project_security_group_name         = (var.project_security_group_name != "" ? var.project_security_group_name : (local.project_name != "" ? "${local.project_name}-sg" : ""))
  project_security_group_type         = var.project_security_group_type

  # Feature: project - network load balancer
  project_load_balancer_use_strategy = var.project_load_balancer_use_strategy
  project_load_balancer_name         = (var.project_load_balancer_name != "" ? var.project_load_balancer_name : (local.project_name != "" ? "${local.project_name}-lb" : ""))
  project_load_balancer_access_cidrs = (
    var.project_load_balancer_access_cidrs != null ? var.project_load_balancer_access_cidrs : (
      length(local.project_admin_cidrs) > 0 ? {
        default = {
          port     = "443"
          protocol = "tcp"
          cidrs    = local.project_admin_cidrs
        }
      } : null
    )
  )

  # Feature: project - domain
  project_domain_use_strategy = var.project_domain_use_strategy
  project_domain              = var.project_domain

  # Feature: Server
  server_use_strategy        = var.server_use_strategy
  server_mod                 = (local.server_use_strategy == "skip" ? 0 : 1)
  server_id                  = var.server_id # only used when selecting a server
  server_name                = (var.server_name != "" ? var.server_name : (local.project_name != "" ? "${local.project_name}-server" : ""))
  server_type                = var.server_type
  server_subnet_name         = (var.server_subnet_name != "" ? var.server_subnet_name : keys(local.project_subnets)[0])
  server_security_group_name = (var.server_security_group_name != "" ? var.server_security_group_name : local.project_security_group_name)
  server_private_ip          = var.server_private_ip

  # Feature: server - image
  server_image_use_strategy = var.server_image_use_strategy
  server_image              = var.server_image
  server_image_type         = var.server_image_type

  # Feature: server - cloud-init
  server_cloudinit_use_strategy = var.server_cloudinit_use_strategy
  server_cloudinit_content      = var.server_cloudinit_content

  # Feature: server - indirect access
  server_indirect_access_use_strategy = var.server_indirect_access_use_strategy

  server_load_balancer_target_groups = (
    local.server_indirect_access_use_strategy == "skip" ? [] :
    (length(var.server_load_balancer_target_groups) > 0 ? var.server_load_balancer_target_groups :
    ["${local.project_load_balancer_name}-${keys(local.project_load_balancer_access_cidrs)[0]}"])
  )

  # Feature: server - direct access
  server_direct_access_use_strategy = var.server_direct_access_use_strategy
  server_access_addresses = (
    var.server_access_addresses != null ? var.server_access_addresses : (
      length(local.project_admin_cidrs) > 0 ? {
        adminSsh = {
          port     = 22
          protocol = "tcp"
          cidrs    = local.project_admin_cidrs
        }
        adminKubectl = {
          port     = 6443
          protocol = "tcp"
          cidrs    = local.project_admin_cidrs
        }
      } : null
  ))
  server_user        = var.server_user
  server_add_domain  = var.server_add_domain
  server_domain_name = var.server_domain_name
  server_domain_zone = var.server_domain_zone
  server_add_eip     = var.server_add_eip

  # Feature: install
  install_use_strategy      = var.install_use_strategy
  install_mod               = (local.install_use_strategy == "skip" ? 0 : local.server_mod)
  local_file_use_strategy   = var.local_file_use_strategy
  download_mod              = (local.local_file_use_strategy == "download" ? local.install_mod : 0)
  local_file_path           = (var.local_file_path != "" ? var.local_file_path : "${abspath(path.root)}/rke2")
  install_rke2_version      = var.install_rke2_version
  install_rpm_channel       = var.install_rpm_channel
  install_remote_file_path  = var.install_remote_file_path
  install_prep_script       = var.install_prep_script
  install_start_prep_script = var.install_start_prep_script
  install_role              = var.install_role
  install_start             = var.install_start
  install_start_timeout     = var.install_start_timeout

  # Feature: config
  config_use_strategy     = var.config_use_strategy # do you want to supply config, use the default, or merge
  config_mod              = (local.config_use_strategy == "default" || local.config_use_strategy == "merge" ? local.server_mod : 0)
  config_default_name     = var.config_default_name
  config_supplied_name    = var.config_supplied_name
  config_supplied_content = var.config_supplied_content
  retrieve_kubeconfig     = var.retrieve_kubeconfig
  config_join_strategy    = var.config_join_strategy
  config_join_url         = var.config_join_url
  config_join_token       = var.config_join_token
  # config_agent_join_token  = var.config_agent_join_token

  join_token = (local.config_mod == 1 ?
    (
      local.config_join_token != "" ? local.config_join_token : # if the user supplied a token, use it
      (
        can(yamldecode(local.config_supplied_content).token) ? # if the user supplied a config with a join_token
        yamldecode(local.config_supplied_content).token :      # use the token from the config
        random_uuid.join_token.result                          # fall back to the random uuid
      )
    ) : "" # leave empty if the config_mod isn't used
  )
  # agent_join_token = (local.config_mod == 1 ?
  #   (
  #     local.config_agent_join_token != "" ? local.config_agent_join_token : # if the user supplied a token, use it
  #     (
  #       can(yamldecode(local.config_supplied_content).agent_token) ? # if the user supplied a config with a join_token
  #       yamldecode(local.config_supplied_content).agent_token :      # use the token from the config
  #       random_uuid.agent_join_token.result                          # fall back to the random uuid
  #     )
  #   ) : "" # leave empty if the config_mod isn't used
  # )

  install_identifier = md5(join("-", [
    # if any of these things change, redeploy rke2
    module.server[0].server.id,
    local.install_rke2_version,
    local.install_start_prep_script,
    local.install_role,
  ]))


  node_external_ip = [(can(module.server[0].server.public_ip) ? module.server[0].server.public_ip : module.server[0].server.private_ip)]
}

module "project" {
  count                       = local.project_mod
  source                      = "rancher/access/aws"
  version                     = "v2.2.1"
  vpc_use_strategy            = local.project_vpc_use_strategy
  vpc_name                    = local.project_vpc_name
  vpc_cidr                    = local.project_vpc_cidr
  subnet_use_strategy         = local.project_subnet_use_strategy
  subnets                     = local.project_subnets
  security_group_use_strategy = local.project_security_group_use_strategy
  security_group_name         = local.project_security_group_name
  security_group_type         = local.project_security_group_type
  load_balancer_use_strategy  = local.project_load_balancer_use_strategy
  load_balancer_name          = local.project_load_balancer_name
  load_balancer_access_cidrs  = local.project_load_balancer_access_cidrs
  domain_use_strategy         = local.project_domain_use_strategy
  domain                      = local.project_domain
}

module "server" {
  count                        = local.server_mod
  depends_on                   = [module.project]
  source                       = "rancher/server/aws"
  version                      = "v1.0.4"
  server_use_strategy          = local.server_use_strategy
  server_id                    = local.server_id
  server_name                  = local.server_name
  server_type                  = local.server_type
  subnet_name                  = local.server_subnet_name
  security_group_name          = local.server_security_group_name
  private_ip                   = local.server_private_ip
  image_use_strategy           = local.server_image_use_strategy
  image                        = local.server_image
  image_type                   = local.server_image_type
  cloudinit_use_strategy       = local.server_cloudinit_use_strategy
  cloudinit_content            = local.server_cloudinit_content
  indirect_access_use_strategy = local.server_indirect_access_use_strategy
  load_balancer_target_groups  = local.server_load_balancer_target_groups
  direct_access_use_strategy   = local.server_direct_access_use_strategy
  server_access_addresses      = local.server_access_addresses
  server_user                  = local.server_user
  add_domain                   = local.server_add_domain
  domain_name                  = local.server_domain_name
  domain_zone                  = local.server_domain_zone
  add_eip                      = local.server_add_eip
}

resource "random_uuid" "join_token" {
  keepers = {
    server = module.server[0].server.id
  }
}

# resource "random_uuid" "agent_join_token" {
#   keepers = {
#     server = module.server[0].server.id
#   }
# }

# the idea here is to provide the least amount of config necessary to get a cluster up and running
# if a user wants to provide their own config, they can put it in the local_file_path or supply it as a string
module "default_config_initial_server" {
  count = ((local.install_role == "server" && local.config_join_strategy == "skip") ? local.config_mod : 0)
  depends_on = [
    module.project,
    module.server,
  ]
  source            = "rancher/rke2-config/local"
  version           = "0.1.4"
  advertise-address = module.server[0].server.private_ip
  tls-san = compact([
    local.server_domain_name,
    local.project_domain,
    module.server[0].server.private_ip,
    (can(module.server[0].server.public_ip) ? module.server[0].server.public_ip : ""),
  ])
  token = local.join_token
  # agent-token      = local.agent_join_token
  node-external-ip = local.node_external_ip
  node-ip          = [module.server[0].server.private_ip]
  node-name        = local.server_name
  local_file_path  = local.local_file_path
  local_file_name  = local.config_default_name
}
module "default_config_additional_server" {
  count = ((local.install_role == "server" && local.config_join_strategy == "join") ? local.config_mod : 0)
  depends_on = [
    module.project,
    module.server,
  ]
  source            = "rancher/rke2-config/local"
  version           = "0.1.4"
  advertise-address = module.server[0].server.private_ip
  token             = local.join_token
  server            = local.config_join_url
  node-external-ip  = local.node_external_ip
  node-ip           = [module.server[0].server.private_ip]
  node-name         = local.server_name
  local_file_path   = local.local_file_path
  local_file_name   = local.config_default_name
}
module "default_config_agent" {
  count = (local.install_role == "agent" ? local.config_mod : 0)
  depends_on = [
    module.project,
    module.server,
  ]
  source           = "rancher/rke2-config/local"
  version          = "0.1.4"
  token            = local.join_token
  server           = local.config_join_url
  node-external-ip = local.node_external_ip
  node-ip          = [module.server[0].server.private_ip]
  node-name        = local.server_name
  local_file_path  = local.local_file_path
  local_file_name  = local.config_default_name
}

module "download" {
  count   = local.download_mod
  source  = "rancher/rke2-download/github"
  version = "v0.1.1"
  release = local.install_rke2_version
  path    = local.local_file_path
}

resource "null_resource" "write_supplied_config" {
  count = (local.config_supplied_content == "" ? 0 : 1)
  triggers = {
    config_content = local.config_supplied_content,
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      set -x
      install -d '${local.local_file_path}'
      cat << EOF > '${local.local_file_path}/${local.config_supplied_name}'
      ${local.config_supplied_content}
      EOF
      chmod 0600 '${local.local_file_path}/${local.config_supplied_name}'
    EOT
  }
}

module "install" {
  count = local.install_mod
  depends_on = [
    module.project,
    module.server,
    module.default_config_initial_server,
    module.default_config_additional_server,
    module.default_config_agent,
    module.download,
  ]
  source                     = "rancher/rke2-install/null"
  version                    = "v1.1.6"
  release                    = local.install_rke2_version
  rpm_channel                = local.install_rpm_channel
  local_file_path            = local.local_file_path
  remote_file_path           = local.install_remote_file_path
  remote_workspace           = module.server[0].image.workfolder
  ssh_ip                     = module.server[0].server.public_ip
  ssh_user                   = local.server_user.user
  role                       = local.install_role
  retrieve_kubeconfig        = local.retrieve_kubeconfig
  install_method             = local.install_use_strategy
  server_prep_script         = local.install_start_prep_script
  server_install_prep_script = local.install_prep_script
  start                      = local.install_start
  start_timeout              = local.install_start_timeout
  identifier                 = local.install_identifier
}
