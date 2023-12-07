# the GITHUB_TOKEN environment variable must be set for this example to work
provider "github" {}
# you must authenticate with AWS in the environment for this example to work
provider "aws" {
  default_tags {
    tags = {
      Id = local.identifier
    }
  }
}

locals {
  email    = "terraform-ci@suse.com"
  name     = "tf-aws-rke2-basic"
  username = "tf-${local.identifier}" # WARNING: This must be less than 32 characters!

  # I don't normally recommend using variables in root modules, but this allows tests to supply their own key and rke2 version
  ssh_key_name = var.ssh_key_name # I want ci to be able to generate a key that is specific to a single pipeline run
  rke2_version = var.rke2_version # I want ci to be able to specify the version of rke2 to test
  identifier   = var.identifier   # I want ci to be able to isolate resources between pipelines
}
resource "random_uuid" "join_token" {}

module "TestBasic" {
  source = "../../" # change this to "rancher/rke2/aws" per https://registry.terraform.io/modules/rancher/rke2/aws/latest
  # version = "v0.0.7" # when using this example you will need to set the version
  name                = local.name
  owner               = local.email
  vpc_name            = "default"
  subnet_name         = "default"
  security_group_name = local.name
  security_group_type = "specific" # you will need to open this up to at least internal if you want to join other servers to this cluster
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name
  local_file_path     = "${abspath(path.root)}/rke2"
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  retrieve_kubeconfig = true
}
