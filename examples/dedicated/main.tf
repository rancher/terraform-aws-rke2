# example of how to set the region if not using aws config or environment variables
provider "aws" {
  region = "us-west-1"
}

locals {
  email               = "terraform-ci@suse.com" # put your email here
  server_count        = 3
  agent_count         = 3
  cluster_size        = local.server_count + local.agent_count
  identifier          = var.identifier                                                   # put a unique identifier here
  prefix              = "tf-aws-rke2-${local.identifier}"                                # this can be anything you want, it makes it marginally easier to find in AWS
  username            = "tf-${local.identifier}"                                         # WARNING: This must be less than 32 characters!
  rke2_version        = var.rke2_version                                                 # put your rke2 version here, must be a valid tag name like v1.21.6+rke2r1
  extra_config        = (var.extra_config_path == "" ? "" : file(var.extra_config_path)) # put your extra config file here
  server_type         = "large"                                                          # https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  image_type          = "rhel-9"                                                         # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  security_group_type = "egress"                                                         # https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  server_prep_script  = file(var.server_prep_script)                                     # put your server prep script here

  # We are generating random names for the servers here, you might want to simplify this for your use case, just pick some names
  # Keep in mind that these names must not be generated using resources, but they can use functions and expressions
  # The map format is { "0" = "name0", "1" = "name1", ... }
  # for example : names = { "0" = "initial", "1" = "secondary", "2" = "tertiary" }
  names                 = { for i in range(local.cluster_size) : tostring(i) => "${local.prefix}-${md5(uuidv5("dns", tostring(i)))}" }
  vpc_cidr              = "172.31.0.0/16" # put the CIDR you want for your VPC here
  subnet_size           = 12              # 12 new bits is a /28 given the /16 vpc_cidr, this changes based on the CIDR size and how large you want your subnets
  subnet_start_position = 4095            # when splitting /16 into /28 chunks, there will be 4095 of them, we are starting at the end
  subnet_cidrs          = { for i in range(local.cluster_size) : local.names[tostring(i)] => cidrsubnet(local.vpc_cidr, local.subnet_size, (local.subnet_start_position - i)) }
  availability_zones    = { for i in range(local.cluster_size) : local.names[tostring(i)] => data.aws_availability_zones.available.names[(i % length(data.aws_availability_zones.available.names))] }
  file_paths            = { for i in range(local.cluster_size) : local.names[tostring(i)] => "${path.root}/${local.names[tostring(i)]}" }
  ssh_key_name          = var.ssh_key_name # put the name of your ssh keypair here
  # ssh_key_content       = file(var.ssh_key_path) # if you want the module to create the keypair object in AWS for you, specify the contents of the public key like this
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_uuid" "join_token" {}

resource "null_resource" "write_extra_config" {
  for_each = (local.extra_config == "" ? {} : local.file_paths)
  triggers = {
    config_content = local.extra_config,
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      set -x
      install -d ${each.value}
      cat << 'EOF' > "${each.value}/51-extra-config.yaml"
      ${local.extra_config}
      EOF
    EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      rm -rf "${each.key}"
    EOT
  }
}

module "InitialServer" {
  depends_on = [
    data.aws_availability_zones.available,
    null_resource.write_extra_config,
    random_uuid.join_token,
  ]
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  name                = local.names["0"] # the name attribute must not depend on a resource
  owner               = local.email
  vpc_name            = local.names["0"]
  vpc_cidr            = local.vpc_cidr
  subnet_name         = local.names["0"]
  subnet_cidr         = local.subnet_cidrs[local.names["0"]]
  availability_zone   = local.availability_zones[local.names["0"]]
  security_group_name = local.names["0"]
  security_group_type = local.security_group_type
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name
  # ssh_key_content     = local.ssh_key_content
  local_file_path     = "${path.root}/${local.names["0"]}"
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  install_method      = "rpm" # requires "egress" security group type
  skip_download       = true
  retrieve_kubeconfig = true
  server_type         = local.server_type
  image_type          = local.image_type
  server_prep_script  = local.server_prep_script
  role                = "server"
}

module "Servers" {
  depends_on = [
    data.aws_availability_zones.available,
    random_uuid.join_token,
    null_resource.write_extra_config,
    module.InitialServer,
  ]
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  for_each            = toset([for i in range(1, local.server_count) : local.names[tostring(i)]]) # "1","2"... less than server_count offset by 1 (initial server)
  name                = each.key
  owner               = local.email
  vpc_name            = local.names["0"] # reuse what we generated with initial server
  subnet_name         = each.key         # each server gets its own subnet
  subnet_cidr         = local.subnet_cidrs[each.key]
  availability_zone   = local.availability_zones[each.key]
  security_group_name = local.names["0"] # reuse what we generated with initial server
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name # reuse what we generated with initial server
  local_file_path     = local.file_paths[each.key]
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  join_url            = module.InitialServer.join_url
  install_method      = "rpm"
  skip_download       = true
  retrieve_kubeconfig = false # we can reuse the kubeconfig downloaded with the initial server
  server_type         = local.server_type
  image_type          = local.image_type
  server_prep_script  = local.server_prep_script
  role                = "server"
}

module "Agents" {
  depends_on = [
    data.aws_availability_zones.available,
    random_uuid.join_token,
    null_resource.write_extra_config,
    module.InitialServer,
  ]
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  for_each            = toset([for i in range(local.server_count, (local.server_count + local.agent_count)) : local.names[tostring(i)]]) # "3","4","5"... less than cluster_size offset by server_count
  name                = each.key
  owner               = local.email
  vpc_name            = local.names["0"] # reuse what we generated with initial server
  subnet_name         = each.key         # each server gets its own subnet
  subnet_cidr         = local.subnet_cidrs[each.key]
  availability_zone   = local.availability_zones[each.key]
  security_group_name = local.names["0"] # reuse what we generated with initial server
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name # reuse what we generated with initial server
  local_file_path     = local.file_paths[each.key]
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  join_url            = module.InitialServer.join_url
  install_method      = "rpm"
  skip_download       = true
  retrieve_kubeconfig = false # we can reuse the kubeconfig downloaded with the initial server
  server_type         = local.server_type
  image_type          = local.image_type
  server_prep_script  = local.server_prep_script
  role                = "agent"
}
