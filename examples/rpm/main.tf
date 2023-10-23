provider "aws" {
  region = "us-east-1" # you can optionally specify the region here
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference
}

locals {
  # I don't normally recommend using variables in root modules
  #   but this allows our test suite to supply a information in ci
  ssh_key_name       = var.ssh_key_name
  rke2_version       = var.rke2_version
  identifier         = var.identifier # simple random string to identify resources
  email              = "terraform-ci@suse.com"
  name               = "tf-aws-rke2-rpm-${local.identifier}"
  username           = "tf-${local.identifier}" # WARNING: This must be less than 32 characters!
  server_prep_script = file("${path.root}/prep.sh")
  local_file_path    = "${path.root}/config" # add custom configs here
}
resource "random_uuid" "join_token" {}

module "aws_rke2_rhel9_rpm" {
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.5" # when using this example you will need to set the version
  join_token          = random_uuid.join_token.result
  name                = local.name
  owner               = local.email
  rke2_version        = local.rke2_version
  security_group_name = local.name
  ssh_key_name        = local.ssh_key_name # your key will need a tag with key 'Name' and value equal to this
  ssh_username        = local.username
  vpc_name            = local.name
  vpc_cidr            = "10.42.0.0/16" # generates a VPC for you, comment this to select a VPC instead
  subnet_name         = local.name
  subnet_cidr         = "10.42.1.0/24" # generates a subnet for you, comment this to select a subnet instead
  availability_zone   = "us-east-1a"   # you can specify an availability zone name here https://us-west-1.console.aws.amazon.com/ec2/home?region=us-east-1#Settings:tab=zones
  image_type          = "rhel-9"       # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  install_method      = "rpm"          # use the RPM install method when installing rke2
  local_file_path     = local.local_file_path
  retrieve_kubeconfig = true                     # get the kubeconfig so we can start using kubernetes locally
  role                = "server"                 # "server" or "agent", "server" for stand alone, see "dedicated" example for setting up clusters where different nodes have dedicated jobs
  security_group_type = "egress"                 # allow downloading packages: https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  server_type         = "small"                  # smallest viable server: https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  server_prep_script  = local.server_prep_script # prep RHEL9 for running rke2
  skip_download       = "true"                   # let the installer download everything
}
