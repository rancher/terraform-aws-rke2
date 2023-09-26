# the provider block is not necessary, I am adding it to show what region I am using so that the availability zone choices make sense
# if you are using an aws config file with a default region, or if you are setting the region in the environment, you can remove this block
provider "aws" {
  region = "us-west-1"
}

locals {
  email    = "terraform-ci@suse.com"
  name     = "tf-aws-rke2-devcluster-${local.identifier}"
  username = "tf-${local.identifier}" # WARNING: This must be less than 32 characters!
  # I don't normally recommend using variables in root modules, but this allows tests to supply their own key and rke2 version
  ssh_key_name = var.ssh_key_name # I want ci to be able to generate a key that is specific to a single pipeline run
  rke2_version = var.rke2_version # I want ci to be able to get the latest version of rke2 to test
  identifier   = var.identifier   # I want ci to be able to isolate resources between pipelines
  cluster_size = 3
}
resource "random_uuid" "join_token" {}

module "TestInitialServer" {
  source              = "../../"
  name                = local.name
  owner               = local.email
  vpc_name            = "default"
  subnet_name         = "default"
  security_group_name = local.name
  security_group_type = "internal"
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name
  local_file_path     = "${path.root}/rke2"
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  retrieve_kubeconfig = true
  availability_zone   = "us-west-1a"
}

module "TestServers" {
  depends_on          = [module.TestInitialServer]
  source              = "../../"
  for_each            = toset([for i in range(1, local.cluster_size) : "${local.name}-${i}"])
  name                = each.key
  owner               = local.email
  vpc_name            = "default"
  subnet_name         = "default"
  security_group_name = local.name # we can reuse the security group created with the initial server
  ssh_username        = local.username
  ssh_key_name        = local.ssh_key_name
  local_file_path     = "${path.root}/rke2"
  skip_download       = true # we can reuse the files downloaded with the initial server
  rke2_version        = local.rke2_version
  join_token          = random_uuid.join_token.result
  join_url            = module.TestInitialServer.join_url
  retrieve_kubeconfig = false # we can reuse the kubeconfig downloaded with the initial server
  availability_zone   = "us-west-1b"
}
