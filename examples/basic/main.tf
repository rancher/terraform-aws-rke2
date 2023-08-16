# this is a basic dev server that has all components built in on a single server

locals {
  email = "terraform-ci@suse.com"
  name  = "terraform-aws-rke2-test-basic"
  # I don't normally recommend using variables in root modules, but this allows tests to supply their own key and rke2 version
  ssh_key_name = var.ssh_key_name # I want ci to be able to generate a key that is specific to a single pipeline run
  rke2_version = var.rke2_version # I want ci to be able to get the latest version of rke2 to test
}
resource "random_uuid" "join_token" {}

module "TestBasic" {
  source              = "../../"
  name                = local.name
  owner               = local.email
  vpc_name            = "default"
  subnet_name         = "default"
  security_group_name = local.name
  security_group_type = "specific"
  ssh_username        = local.name
  ssh_key_name        = local.ssh_key_name
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
}
