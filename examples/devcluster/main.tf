# the GITHUB_TOKEN environment variable must be set for this example to work
provider "github" {}
# you must authenticate with AWS in the environment for this example to work
provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      Id = local.identifier
    }
  }
}

locals {
  owner        = "terraform-ci@suse.com" # put your email here
  ssh_key_name = var.ssh_key_name        # this must already exist in AWS, it must have a tag with 'Name' = <this value>
  # ssh_key_content       = file(var.ssh_key_path) # if you want the module to create the keypair object in AWS for you, specify the contents of the public key like this
  rke2_version         = var.rke2_version # the exact release tag, eg. v1.28.2+rke2r1
  identifier           = var.identifier   # simple random string to identify resources
  email                = "terraform-ci@suse.com"
  prefix               = "tf-aws-rke2-dev-${substr(local.identifier, 0, 4)}" # id in name prevents ci collisions
  username             = "tf-${local.identifier}"                            # WARNING: This must be less than 32 characters!
  server_prep_script   = file("${abspath(path.root)}/prep.sh")               # a script that will run before start, after install
  configs              = "${abspath(path.root)}/config"                      # add custom configs here, this is added to all servers, see "dedicated" example to place different configs on different nodes
  cluster_size         = 3                                                   # this example provisions all servers the same, see the "dedicated" example to alter configs and roles
  server_type          = "small"                                             # https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  image_type           = "rhel-8"                                            # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  extra_config_content = file("${local.configs}/config.yaml")

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
  file_paths            = { for i in range(local.cluster_size) : local.names[tostring(i)] => "${abspath(path.root)}/${local.names[tostring(i)]}" }
}

data "aws_availability_zones" "available" {
  state = "available"
}
resource "random_uuid" "join_token" {}

resource "null_resource" "write_configs" {
  for_each = local.names
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      set -x
      install -d '${abspath(path.root)}/${each.value}'
      cp ${local.configs}/* ${abspath(path.root)}/${each.value}
    EOT
  }
}

module "InitialServer" {
  depends_on = [
    data.aws_availability_zones.available,
    null_resource.write_configs,
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
  security_group_type = "egress" # https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name
  # ssh_key_content     = local.ssh_key_content
  local_file_path      = "${abspath(path.root)}/${local.names["0"]}"
  rke2_version         = local.rke2_version
  join_token           = random_uuid.join_token.result
  install_method       = "rpm" # requires "egress" security group type
  skip_download        = true
  retrieve_kubeconfig  = true
  server_type          = local.server_type
  image_type           = local.image_type
  server_prep_script   = local.server_prep_script
  extra_config_content = local.extra_config_content
}

module "Servers" {
  depends_on = [
    data.aws_availability_zones.available,
    random_uuid.join_token,
    null_resource.write_configs,
    module.InitialServer,
  ]
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  for_each             = toset([for i in range(1, local.cluster_size) : local.names[tostring(i)]]) # "1","2","3"... less than cluster_size
  name                 = each.key
  owner                = local.email
  vpc_name             = local.names["0"] # reuse what we generated with initial server
  subnet_name          = each.key         # each server gets its own subnet
  subnet_cidr          = local.subnet_cidrs[each.key]
  availability_zone    = local.availability_zones[each.key]
  security_group_name  = local.names["0"] # reuse what we generated with initial server
  ssh_username         = local.username
  ssh_key_name         = local.ssh_key_name # reuse what we generated with initial server
  local_file_path      = local.file_paths[each.key]
  rke2_version         = local.rke2_version
  join_token           = random_uuid.join_token.result
  join_url             = module.InitialServer.join_url
  install_method       = "rpm"
  skip_download        = true
  retrieve_kubeconfig  = false # we can reuse the kubeconfig downloaded with the initial server
  server_type          = local.server_type
  image_type           = local.image_type
  server_prep_script   = local.server_prep_script
  extra_config_content = local.extra_config_content
}
