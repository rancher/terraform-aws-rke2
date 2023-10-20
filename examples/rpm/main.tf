
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
}
resource "random_uuid" "join_token" {}

module "aws_rke2_rhel9_rpm" {
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  join_token          = random_uuid.join_token.result
  name                = local.name
  owner               = local.email
  rke2_version        = local.rke2_version
  security_group_name = local.name
  ssh_key_name        = local.ssh_key_name
  ssh_username        = local.username
  subnet_name         = "default" # look for a subnet with the "Name" tag and value "default"
  vpc_name            = "default" # look for a vpc with the "Name" tag and value "default"
  #availability_zone   = ""                # use the default az for the subnet
  image_type     = "rhel-9" # https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
  install_method = "rpm"    # use the RPM install method when installing rke2
  #join_url            = ""                # only provision one server
  local_file_path = "${path.root}/rke2" # place in root directory under ./rke2
  #remote_file_path    = ""                  # no special requirements for remote path
  retrieve_kubeconfig = true
  role                = "server"
  #security_group_ip   = ""                       # discover my IP
  security_group_type = "egress"                 # allow downloading packages: https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
  server_type         = "small"                  # smallest viable server: https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
  server_prep_script  = local.server_prep_script # prep OS for running rke2
  skip_download       = "true"                   # let the installer download everything
  #ssh_key_content     = ""                       # use the key I have already set up (ssh_key_name)
  #subnet_cidr         = ""                       # use the subnet I have already set up (subnet_name)
  #vpc_cidr            = ""                       # use the vpc I have already set up (vpc_name)
}
