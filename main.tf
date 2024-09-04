locals {
  # Feature: Project
  project_use_strategy     = var.project_use_strategy
  project_mod              = (local.project_use_strategy == "skip" ? 0 : 1)
  project_name             = var.project_name
  project_admin_cidrs      = var.project_admin_cidrs
  project_vpc_use_strategy = var.project_vpc_use_strategy
  project_vpc_name         = (var.project_vpc_name != "" ? var.project_vpc_name : (local.project_name != "" ? "${local.project_name}-vpc" : ""))
  project_vpc_type         = var.project_vpc_type
  project_vpc_public       = var.project_vpc_public
  project_vpc_zones        = (var.project_vpc_zones != "" ? var.project_vpc_zones : data.aws_availability_zones.available.names)

  # Feature: project - subnets
  project_subnet_use_strategy = var.project_subnet_use_strategy
  project_subnet_names        = var.project_subnet_names


  # Feature: project - security groups
  project_security_group_use_strategy = var.project_security_group_use_strategy
  project_security_group_name         = (var.project_security_group_name != "" ? var.project_security_group_name : (local.project_name != "" ? "${local.project_name}-sg" : ""))
  project_security_group_type         = var.project_security_group_type

  # Feature: project - network load balancer
  project_load_balancer_use_strategy = var.project_load_balancer_use_strategy
  project_load_balancer_name         = (var.project_load_balancer_name != "" ? var.project_load_balancer_name : (local.project_name != "" ? "${local.project_name}-lb" : ""))
  project_load_balancer_access_cidrs = (
    var.project_load_balancer_access_cidrs != null ?
    # use the provided list of cidrs
    var.project_load_balancer_access_cidrs : (

      # use the project's admin cidrs if no cidrs are provided
      length(local.project_admin_cidrs) > 0 ? {
        default = {
          port        = "443"
          protocol    = "tcp"
          ip_family   = (local.project_vpc_type == "ipv6" ? "ipv6" : "ipv4")
          cidrs       = local.project_admin_cidrs
          target_name = "${local.project_name}-default"
        }
      } :

      # null if no admin cidrs and no provided cidrs
      null
    )
  )

  # Feature: project - domain
  project_domain_use_strategy = var.project_domain_use_strategy
  project_domain              = var.project_domain
  project_domain_zone         = var.project_domain_zone
  project_cert_use_strategy   = var.project_domain_cert_use_strategy

  # Dev note: make sure not to depend on the project when deploying the server, we want to be able to skip the project
  # Feature: Server
  server_use_strategy        = var.server_use_strategy
  server_mod                 = (local.server_use_strategy == "skip" ? 0 : 1)
  server_id                  = var.server_id # only used when selecting a server
  server_name                = (var.server_name != "" ? var.server_name : (local.project_name != "" ? "${local.project_name}-server" : ""))
  server_type                = var.server_type
  server_security_group_name = (var.server_security_group_name != "" ? var.server_security_group_name : local.project_security_group_name)
  server_private_ip          = var.server_private_ip
  server_ip_family = (
    var.server_ip_family != "" ? var.server_ip_family :
    local.project_vpc_type != "" ? local.project_vpc_type :
    "ipv4"
  )

  project_subnets = (length(module.project) > 0 ? module.project[0].subnets : null)
  # tflint-ignore: terraform_unused_declarations
  fail_no_subnets = (
    (
      local.project_mod == 1 &&
      local.project_subnet_use_strategy == "create" &&
      local.project_subnets != null &&
      (local.project_subnets == null ? false : (length(local.project_subnets) == 0 ? true : false))
    ) ?
    one([jsonencode(local.project_subnets), "missing_project_subnets"]) :
    false
  )
  first_project_subnet    = (local.project_subnets != null ? local.project_subnets[keys(local.project_subnets)[0]] : null)
  first_project_subnet_az = (local.first_project_subnet != null ? local.first_project_subnet.availability_zone : null)
  server_az               = (var.server_availability_zone != "" ? var.server_availability_zone : local.first_project_subnet_az)

  # tflint-ignore: terraform_unused_declarations
  fail_no_server_az = ((local.server_mod == 1 && local.server_az == null) ? one([local.server_az, "missing_server_availability_zone"]) : false)

  server_subnet_name = (
    local.project_mod == 1 ? [for s in module.project[0].subnets : s.tags.Name if s.availability_zone == local.server_az][0] :
    var.server_subnet_name
  )

  # tflint-ignore: terraform_unused_declarations
  fail_no_server_subnet = ((local.server_mod == 1 && local.server_subnet_name == "") ? one([local.server_subnet_name, "missing_server_subnet_name"]) : false)

  # Feature: server - image
  server_image_use_strategy = var.server_image_use_strategy
  server_image              = var.server_image
  server_image_type         = var.server_image_type

  # Feature: server - cloud-init
  server_cloudinit_use_strategy = var.server_cloudinit_use_strategy
  server_cloudinit_content      = var.server_cloudinit_content

  # Feature: server - indirect access
  server_indirect_access_use_strategy = var.server_indirect_access_use_strategy
  server_load_balancer_target_groups = ( # WARNING! this must not be derived from resource output
    # use specified target groups
    length(var.server_load_balancer_target_groups) > 0 ?
    var.server_load_balancer_target_groups :

    # use project target groups if specified
    length(local.project_load_balancer_access_cidrs) > 0 ?
    [for tg in local.project_load_balancer_access_cidrs : tg.target_name] :

    # no target groups found
    null
  )

  # Feature: server - direct access
  server_direct_access_use_strategy = var.server_direct_access_use_strategy
  server_access_addresses           = var.server_access_addresses

  server_access = (
    length(local.server_access_addresses) > 0 ? local.server_access_addresses :
    length(local.project_admin_cidrs) > 0 ? {
      adminSsh = {
        port      = 22
        protocol  = "tcp"
        ip_family = (local.project_vpc_type == "ipv6" ? "ipv6" : "ipv4")
        cidrs     = local.project_admin_cidrs
      }
    } :
    null
  )
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
  config_mod              = ((local.config_use_strategy == "default" || local.config_use_strategy == "merge") ? local.server_mod : 0)
  config_default_name     = var.config_default_name
  config_supplied_name    = var.config_supplied_name
  config_supplied_content = var.config_supplied_content
  retrieve_kubeconfig     = var.retrieve_kubeconfig
  config_join_strategy    = var.config_join_strategy
  config_join_url         = var.config_join_url
  config_join_token       = var.config_join_token

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
  # rke2 has a max range of /108, so all cidrs must be /108 or greater
  # since the VPC automatically gets a /56, we need to add 52 bits to get to /108
  # terraform's cidrsubnets has a max newbits of 32, so we need a midway point to get to /108
  cluster_cidr_ipv6_starting_cidr  = (length(module.project) > 0 ? split("/", module.project[0].vpc.ipv6_cidr)[1] : "")
  cluster_cidr_ipv4_starting_cidr  = (length(module.project) > 0 ? split("/", module.project[0].vpc.ipv4_cidr)[1] : "")
  cluster_cidr_ipv6_midway_newbits = 32
  cluster_cidr_ipv6_midway = (
    can(cidrsubnet(module.project[0].vpc.ipv6_cidr, local.cluster_cidr_ipv6_midway_newbits, 0)) ?
    cidrsubnet(module.project[0].vpc.ipv6_cidr, local.cluster_cidr_ipv6_midway_newbits, 0) :
    ""
  )
  cluster_cidr_ipv6_newbits = (
    length(module.project) > 0 ?
    (108 - (local.cluster_cidr_ipv6_starting_cidr + local.cluster_cidr_ipv6_midway_newbits)) :
    0
  )
  cluster_cidr_ipv4_newbits = (length(module.project) > 0 ? length(local.project_subnets) : 0)
  cluster_cidr = (
    # specified
    length(var.config_cluster_cidr) > 0 ? var.config_cluster_cidr :
    # ipv6 unspecified
    length(module.project) > 0 && local.project_vpc_type == "ipv6" ? [cidrsubnets(local.cluster_cidr_ipv6_midway, local.cluster_cidr_ipv6_newbits, local.cluster_cidr_ipv6_newbits)[0]] :
    # ipv4 unspecified
    length(module.project) > 0 ? [cidrsubnets(module.project[0].vpc.ipv4_cidr, local.cluster_cidr_ipv4_newbits, local.cluster_cidr_ipv4_newbits)[0]] :
    # default
    []
  )
  service_cidr = (
    # specified
    length(var.config_service_cidr) > 0 ? var.config_service_cidr :
    # ipv6 unspecified
    length(module.project) > 0 && local.project_vpc_type == "ipv6" ? [cidrsubnets(local.cluster_cidr_ipv6_midway, local.cluster_cidr_ipv6_newbits, local.cluster_cidr_ipv6_newbits)[1]] :
    # ipv4 unspecified
    length(module.project) > 0 ? [cidrsubnets(module.project[0].vpc.ipv4_cidr, local.cluster_cidr_ipv4_newbits, local.cluster_cidr_ipv4_newbits)[1]] :
    # default
    []
  )
  cluster_cidr_mask_size = (
    length(module.project) > 0 ?
    (
      local.project_vpc_type == "ipv6" ?
      (local.cluster_cidr_ipv6_starting_cidr + local.cluster_cidr_ipv6_midway_newbits + local.cluster_cidr_ipv6_newbits) :
      (local.cluster_cidr_ipv4_starting_cidr + local.cluster_cidr_ipv4_newbits)
    ) :
    length(local.cluster_cidr) > 0 ? split("/", local.cluster_cidr[0])[1] :
    local.server_ip_family == "ipv6" ? 128 :
    16
  )
}

data "aws_availability_zones" "available" {
  state = "available"
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

resource "random_uuid" "join_token" {
  keepers = {
    server = (can(module.server[0].server.id) ? module.server[0].server.id : "")
  }
}

module "download" {
  count   = local.download_mod
  source  = "rancher/rke2-download/github"
  version = "v0.1.1"
  release = local.install_rke2_version
  path    = local.local_file_path
}

resource "random_pet" "server" {
  keepers = {
    # regenerate the pet name when the identifier changes
    identifier = local.project_name
  }
  length = 1
}

module "project" {
  count                       = local.project_mod
  source                      = "rancher/access/aws"
  version                     = "v3.1.5"
  vpc_use_strategy            = local.project_vpc_use_strategy
  vpc_name                    = local.project_vpc_name
  vpc_type                    = local.project_vpc_type
  vpc_zones                   = local.project_vpc_zones
  vpc_public                  = local.project_vpc_public
  subnet_use_strategy         = local.project_subnet_use_strategy
  subnet_names                = local.project_subnet_names
  security_group_use_strategy = local.project_security_group_use_strategy
  security_group_name         = local.project_security_group_name
  security_group_type         = local.project_security_group_type
  load_balancer_use_strategy  = local.project_load_balancer_use_strategy
  load_balancer_name          = local.project_load_balancer_name
  load_balancer_access_cidrs  = local.project_load_balancer_access_cidrs
  domain_use_strategy         = local.project_domain_use_strategy
  domain_zone                 = local.project_domain_zone
  domain                      = local.project_domain
  cert_use_strategy           = local.project_cert_use_strategy
}

# AWS is having some timing issues with this resource, so find it before moving on
data "aws_security_group" "general_info" {
  count = local.server_mod
  depends_on = [
    module.project
  ]
  filter {
    name   = "tag:Name"
    values = [local.server_security_group_name]
  }
  timeouts {
    read = "40m"
  }
}

module "server" {
  count = local.server_mod
  depends_on = [
    module.project,
    data.aws_security_group.general_info,
  ]
  source                       = "rancher/server/aws"
  version                      = "v1.3.1"
  image_use_strategy           = local.server_image_use_strategy
  image                        = local.server_image
  image_type                   = local.server_image_type
  server_use_strategy          = local.server_use_strategy
  server_id                    = local.server_id
  server_name                  = local.server_name
  server_type                  = local.server_type
  server_ip_family             = local.server_ip_family
  cloudinit_use_strategy       = local.server_cloudinit_use_strategy
  cloudinit_content            = local.server_cloudinit_content
  subnet_name                  = local.server_subnet_name
  security_group_name          = local.server_security_group_name
  private_ip                   = local.server_private_ip
  indirect_access_use_strategy = local.server_indirect_access_use_strategy
  load_balancer_target_groups  = local.server_load_balancer_target_groups
  direct_access_use_strategy   = local.server_direct_access_use_strategy
  server_access_addresses      = local.server_access
  server_user                  = local.server_user
  add_domain                   = local.server_add_domain
  domain_name                  = local.server_domain_name
  domain_zone                  = local.server_domain_zone
  add_eip                      = local.server_add_eip
}

# the idea here is to provide the least amount of config necessary to get a cluster up and running
# if a user wants to provide their own config, they can put it in the local_file_path or supply it as a string
module "default_config" {
  count = local.config_mod
  depends_on = [
    random_uuid.join_token,
    module.project,
    module.server,
  ]
  source  = "rancher/rke2-config/local"
  version = "v0.1.4"
  tls-san = distinct(compact([
    "${local.project_domain}.${local.project_domain_zone}",
  ]))
  token                       = local.join_token
  server                      = (local.config_join_strategy == "join" ? local.config_join_url : null)
  node-external-ip            = [module.server[0].server.public_ip]
  node-ip                     = [module.server[0].server.private_ip]
  node-name                   = local.server_name
  advertise-address           = module.server[0].server.private_ip
  cluster-cidr                = (local.install_role == "server" && local.server_ip_family == "ipv6" ? local.cluster_cidr : null)
  service-cidr                = (local.install_role == "server" && local.server_ip_family == "ipv6" ? local.service_cidr : null)
  kube-controller-manager-arg = (local.install_role == "server" && local.server_ip_family == "ipv6" ? ["--node-cidr-mask-size=${local.cluster_cidr_mask_size}"] : null)
  local_file_path             = local.local_file_path
  local_file_name             = local.config_default_name
}

module "install" {
  count = local.install_mod
  depends_on = [
    random_uuid.join_token,
    module.project,
    module.server,
    module.default_config,
    module.download,
  ]
  source                     = "rancher/rke2-install/null"
  version                    = "v1.3.0"
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
  identifier = md5(join("-", [
    # if any of these things change, redeploy rke2
    module.server[0].server.id,
    local.install_rke2_version,
    local.install_start_prep_script,
    local.install_role,
  ]))
}
