provider "github" {}
provider "aws" {
  region = "us-west-1"
}

locals {
  rke2_version       = "v1.28.4+rke2r1"
  identifier         = "lvex"
  email              = "example@example.com"
  username           = "example"
  name               = "live-rke2-${local.identifier}"
  server_prep_script = file("${path.root}/prep.sh")
  local_file_path    = "${abspath(path.root)}/config" # add custom configs here
  ip                 = var.ip
  ssh_key_name       = local.name
}

resource "random_uuid" "join_token" {}

module "aws_rke2_rhel9_rpm" {
  source              = "rancher/rke2/aws"
  version             = "v0.1.9"
  join_token          = random_uuid.join_token.result
  name                = local.name
  owner               = local.email
  rke2_version        = local.rke2_version
  security_group_name = local.name
  security_group_ip   = local.ip
  ssh_key_name        = local.ssh_key_name
  ssh_key_content     = file("${path.root}/ssh.pub")
  ssh_username        = local.username
  vpc_name            = local.name
  vpc_cidr            = "10.42.0.0/16" # generates a VPC for you, comment this to select a VPC instead
  subnet_name         = local.name
  subnet_cidr         = "10.42.1.0/24" # generates a subnet for you, comment this to select a subnet instead
  availability_zone   = "us-west-1b"   # you can specify an availability zone name here https://us-west-1.console.aws.amazon.com/ec2/home?region=us-west-1#Settings:tab=zones, must match region!
  image_type          = "rhel-9"       # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  install_method      = "rpm"          # use the RPM install method when installing rke2
  local_file_path     = local.local_file_path
  role                = "server"                 # "server" or "agent", "server" for stand alone, see "dedicated" example for setting up clusters where different nodes have dedicated jobs
  security_group_type = "egress"                 # allow downloading packages: https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  server_type         = "small"                  # smallest viable server: https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  server_prep_script  = local.server_prep_script # prep RHEL9 for running rke2
  skip_download       = true                     # let the installer download everything
  retrieve_kubeconfig = false                    # when set to true you can set the KUBECONFIG environment variable to the resulting file and control your cluster remotely
}
