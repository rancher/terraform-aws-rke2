locals {
  email    = "terraform-ci@suse.com"
  name     = "tf-aws-rke2-${local.identifier}"
  username = "tf-${local.identifier}" # WARNING: This must be less than 32 characters!
  # I don't normally recommend using variables in root modules, but this allows tests to supply their own key and rke2 version
  ssh_key_name = var.ssh_key_name # I want ci to be able to generate a key that is specific to a single pipeline run
  rke2_version = var.rke2_version # I want ci to be able to get the latest version of rke2 to test
  identifier   = var.identifier   # I want ci to be able to isolate resources between pipelines

  # these names have no significance, they are just unique (they are types of gecko)
  # we don't want to assume any priority in the order that the servers are created
  # that way, later on, if we need to remove or add a server nothing seems out of place
  # since the names have no priority, adding, removing, or changing them will not seem weird
  # "banded", "day", "lygodactylus", "tokay", "crested"
  # if these had some intuitive order, then you might have something like "1,2,3,4,5" and if you had to remove "3" and add another it would be "1,2,4,5,6" or "1,2,4,5,3"
}
resource "random_uuid" "join_token" {}

module "InitialServer" {
  depends_on = [
    random_uuid.join_token,
  ]
  source = "../../"
  # Warning! These names should not rely on a resource. Terraform needs to be able to read the name at plan time.
  name                = "${local.name}-server-initial"
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
}

module "Servers" {
  depends_on = [
    random_uuid.join_token,
    module.InitialServer,
  ]
  source = "../../"
  # Warning! These names should not rely on a resource. Terraform needs to be able to read the name at plan time.
  for_each            = toset(["${local.name}-server-day", "${local.name}-server-banded"])
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
  join_url            = module.InitialServer.join_url
  role                = "server"
  retrieve_kubeconfig = false # we can reuse the kubeconfig downloaded with the initial server
}

module "Agents" {
  depends_on = [
    random_uuid.join_token,
    module.InitialServer,
  ]
  source = "../../"
  # Warning! These names should not rely on a resource. Terraform needs to be able to read the name at plan time.
  for_each            = toset(["${local.name}-agent-lygodactylus", "${local.name}-agent-tokay", "${local.name}-agent-crested"])
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
  join_url            = module.InitialServer.join_url
  role                = "agent"
}
