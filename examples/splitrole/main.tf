provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.email
    }
  }
}
provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

locals {
  # Module inputs
  template_path    = abspath("${path.module}/templates")
  rke2_module_path = abspath("${path.root}/../../")
  deploy_path      = abspath("${path.root}/child_modules")
  data_path        = var.data_path == "" ? var.data_path : abspath("${path.root}/data")

  # Project inputs
  identifier       = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  email            = "terraform-ci@suse.com"
  example          = "splitrole"
  project_name     = substr("tf-${local.identifier}-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}", 0, 20)
  ip_family        = var.ip_family
  runner_ip        = (var.runner_ip == "" ? chomp(data.http.myip.response_body) : var.runner_ip) # "runner" is the server running Terraform
  project_domain   = lower(local.project_name)
  zone             = var.zone # DNS zone
  k8s_target_group = substr(lower("${local.project_name}-kubectl"), 0, 32)

  # Global node variables
  image              = var.os
  install_method     = var.install_method
  username           = substr(lower(local.project_name), 0, 25)
  ssh_key            = var.key
  ssh_key_name       = var.key_name
  cloudinit_strategy = ((local.image == "sle-micro-55" || local.image == "cis-rhel-8") ? "skip" : "default")
  rke2_version       = var.rke2_version
  cni                = var.cni
  cni_config         = templatefile("${path.module}/config_files/config.yaml.tftpl", { cni = local.cni })
  download           = (local.install_method == "tar" ? "download" : "skip")
  local_file_path    = abspath("${path.root}/rke2")
  subnets            = [for s in module.project.project_subnets : s]
  install_prep_script_file = (
    strcontains(local.image, "sles") ? "${local.template_path}/suse_prep.sh.tftpl" :
    strcontains(local.image, "rhel") ? "${local.template_path}/rhel_prep.sh.tftpl" :
    strcontains(local.image, "rocky") ? "${local.template_path}/rhel_prep.sh.tftpl" :
    strcontains(local.image, "multi-linux") ? "${local.template_path}/multi-linux_prep.sh.tftpl" :
    strcontains(local.image, "ubuntu") ? "${local.template_path}/ubuntu_prep.sh.tftpl" :
    ""
  )
  install_prep_script = (local.install_prep_script_file == "" ? "" :
    templatefile(local.install_prep_script_file, {
      install_method = local.install_method,
      ip_family      = local.ip_family,
      image          = local.image,
    })
  )
  workfolder = (
    strcontains(local.image, "cis-rhel-8") ? "/var/tmp" :
    strcontains(local.image, "cis-rhel-9") ? "/opt/bootstrap" :
    "/home/${local.username}"
  )

  cis_rhel_extra_config = yamlencode({
    kube-proxy-arg = ["--nodeport-addresses=primary"]
  })

  explicit_ingress_controller_config = yamlencode({
    ingress-controller = ["traefik"]
  })

  # Type node variables
  configs = {
    control_plane     = <<-EOT
      node-taint:
        - "CriticalAddonsOnly=true:NoExecute"
      ${local.cni_config}
      ${local.explicit_ingress_controller_config}
      ${strcontains(local.image, "cis-rhel") ? local.cis_rhel_extra_config : ""}
    EOT
    control_plane_ndb = <<-EOT
      node-taint:
        - "CriticalAddonsOnly=true:NoExecute"
      disable-etcd: true
      ${local.cni_config}
      ${local.explicit_ingress_controller_config}
      ${strcontains(local.image, "cis-rhel") ? local.cis_rhel_extra_config : ""}
    EOT
    database          = <<-EOT
      disable-apiserver: true
      disable-controller-manager: true
      disable-scheduler: true
      ${local.cni_config}
      ${local.explicit_ingress_controller_config}
      ${strcontains(local.image, "cis-rhel") ? local.cis_rhel_extra_config : ""}
    EOT
    worker            = <<-EOT
      ${local.cni_config}
      ${local.explicit_ingress_controller_config}
      ${strcontains(local.image, "cis-rhel") ? local.cis_rhel_extra_config : ""}
    EOT
    all_in_one        = <<-EOT
      ${local.cni_config}
      ${local.explicit_ingress_controller_config}
      ${strcontains(local.image, "cis-rhel") ? local.cis_rhel_extra_config : ""}
    EOT
  }

  # Specific Node Variables
  nodes_id = {
    initial_node  = lower(substr("${local.project_name}-${md5(uuidv5("dns", "initial-node"))}", 0, 25))
    cp_node_two   = lower(substr("${local.project_name}-${md5(uuidv5("dns", "cp-node-two"))}", 0, 25))
    cp_node_three = lower(substr("${local.project_name}-${md5(uuidv5("dns", "cp-node-three"))}", 0, 25))
    wk_node_one   = lower(substr("${local.project_name}-${md5(uuidv5("dns", "wk-node-one"))}", 0, 25))
    wk_node_two   = lower(substr("${local.project_name}-${md5(uuidv5("dns", "wk-node-two"))}", 0, 25))
    wk_node_three = lower(substr("${local.project_name}-${md5(uuidv5("dns", "wk-node-three"))}", 0, 25))
  }
  nodes_info = {
    initial_node = {
      name          = local.nodes_id.initial_node
      domain        = local.nodes_id.initial_node
      subnet        = local.subnets[(0 % length(local.subnets))].tags.Name
      az            = local.subnets[(0 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.initial_node}/data"
      instance_type = "medium"
      rke2_role     = "server" # server or agent
      config        = local.configs["control_plane"]
    }
    cp-node-two = {
      name          = local.nodes_id.cp_node_two
      domain        = local.nodes_id.cp_node_two
      subnet        = local.subnets[(1 % length(local.subnets))].tags.Name
      az            = local.subnets[(1 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.cp_node_two}/data"
      instance_type = "medium"
      rke2_role     = "server" # server or agent
      config        = local.configs["control_plane"]
    }
    cp-node-three = {
      name          = local.nodes_id.cp_node_three
      domain        = local.nodes_id.cp_node_three
      subnet        = local.subnets[(2 % length(local.subnets))].tags.Name
      az            = local.subnets[(2 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.cp_node_three}/data"
      instance_type = "medium"
      rke2_role     = "server" # server or agent
      config        = local.configs["control_plane"]
    }
    wk-node-one = {
      name          = local.nodes_id.wk_node_one
      domain        = local.nodes_id.wk_node_one
      subnet        = local.subnets[(3 % length(local.subnets))].tags.Name
      az            = local.subnets[(3 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.wk_node_one}/data"
      instance_type = "medium"
      rke2_role     = "agent" # server or agent
      config        = local.configs["worker"]
    }
    wk-node-two = {
      name          = local.nodes_id.wk_node_two
      domain        = local.nodes_id.wk_node_two
      subnet        = local.subnets[(4 % length(local.subnets))].tags.Name
      az            = local.subnets[(4 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.wk_node_two}/data"
      instance_type = "medium"
      rke2_role     = "agent" # server or agent
      config        = local.configs["worker"]
    }
    wk-node-three = {
      name          = local.nodes_id.wk_node_three
      domain        = local.nodes_id.wk_node_three
      subnet        = local.subnets[(5 % length(local.subnets))].tags.Name
      az            = local.subnets[(5 % length(local.subnets))].availability_zone
      file_path     = "${local.local_file_path}/${local.nodes_id.wk_node_three}/data"
      instance_type = "medium"
      rke2_role     = "agent" # server or agent
      config        = local.configs["worker"]
    }
  }
  initial_node_info = { for k, v in local.nodes_info : k => v if k == "initial_node" }
  other_nodes_info  = { for k, v in local.nodes_info : k => v if k != "initial_node" }
}

# CIS images are not supported on IPv6 only deployments due to kernel modifications with how AWS IPv6 works (dhcpv6)
check "cis_ipv6_compatibility" {
  assert {
    condition     = !(local.image == "rhel-8-cis" && local.ip_family == "ipv6")
    error_message = "CIS images are not compatible with IPv6 deployments due to kernel modifications with how AWS IPv6 works (dhcpv6)"
  }
}

# Ubuntu images do not support rpm install method
check "ubuntu_rpm_compatibility" {
  assert {
    condition     = !(strcontains(local.image, "ubuntu") && local.install_method == "rpm")
    error_message = "Ubuntu images do not support rpm install method"
  }
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "project" {
  depends_on = [
    data.http.myip,
    data.aws_availability_zones.available,
  ]
  source                              = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_use_strategy                = "create"
  project_vpc_use_strategy            = "create"
  project_vpc_name                    = "${local.project_name}-vpc"
  project_vpc_zones                   = data.aws_availability_zones.available.names
  project_vpc_type                    = local.ip_family
  project_vpc_public                  = local.ip_family == "ipv6" ? false : true # ipv6 addresses assigned by AWS are always public
  project_subnet_use_strategy         = "create"
  project_subnet_names                = [for z in data.aws_availability_zones.available.names : "${local.project_name}-subnet-${z}"]
  project_security_group_use_strategy = "create"
  project_security_group_name         = "${local.project_name}-sg"
  project_security_group_type         = (local.install_method == "rpm" ? "egress" : "project") # rpm install requires downloading dependencies
  project_load_balancer_use_strategy  = "create"
  project_load_balancer_name          = "${local.project_name}-lb"
  project_load_balancer_access_cidrs = {
    "kubectl" = {
      port        = "6443"
      protocol    = "tcp"
      ip_family   = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs       = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
      target_name = local.k8s_target_group
    }
  }
  project_domain_use_strategy      = "create"
  project_domain                   = local.project_domain
  project_domain_zone              = local.zone
  project_domain_cert_use_strategy = "skip"
  server_use_strategy              = "skip"
}

# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# In this example I am using Terraform resources to orchestrate Terraform
#   I felt this was the best way to accomplish the goal without incurring additional dependencies
# The configuration we are orchestrating isn't hard coded, we will be generating the config from template files.
# To deploy some other config we need:
# 1. an absolute path to the config files to deploy or a list of files to deploy
# 2. an absolute path that we can put our implementation
# 3. an absolute path that we can use as a tmp or scratch area for files and things that are only necessary during the process
# 4. an absolute path to the module or list of module files since we are using the latest version of the module (via relative path) and not a released version we need
# the best organization for all of this would be:
# deploy_path/rke2_module
# deploy_path/rke2_module/initial (initial is also cp_one)
# deploy_path/rke2_module/cp_two
# deploy_path/rke2_module/cp_three
# deploy_path/rke2_module/wk_one
# deploy_path/rke2_module/wk_two
# deploy_path/rke2_module/wk_three
# where rke2_module is generated from the files in ../../
# the modules are generated using templates found in ./templates
# each module will be its own Terraform process with its own state running parallel
# except the initial node which will be run before anything else
module "deploy_initial_node" {
  depends_on = [
    module.project,
  ]
  source = "./modules/deploy"
  inputs = <<-EOT
    identifier                  = "${local.identifier}"
    email                       = "${local.email}"
    project_domain              = "${local.project_domain}"
    zone                        = "${local.zone}"
    node_info                   = <<-EOD
    ${jsonencode(local.initial_node_info.initial_node)}
    EOD
    project_security_group_name = "${module.project.project_security_group.name}"
    image                       = "${local.image}"
    ip_family                   = "${local.ip_family}"
    cloudinit_strategy          = "${local.cloudinit_strategy}"
    k8s_target_group            = "${local.k8s_target_group}"
    runner_ip                   = "${local.runner_ip}"
    username                    = "${local.username}"
    ssh_key                     = "${local.ssh_key}"
    ssh_key_name                = "${local.ssh_key_name}"
    workfolder                  = "${local.workfolder}"
    install_method              = "${local.install_method}"
    download                    = "${local.download}"
    rke2_version                = "${local.rke2_version}"
    install_prep_script         = "${local.install_prep_script}"
  EOT
  template_files = { # map of relative path => absolute path for files that will be copied to the deploy path
    "./versions.tf" = abspath("${path.module}/config_files/versions.tf")
  }
  generated_files = { # map of relative file path to content, the new file will be placed in the deploy path respecting the relative path
    "./main.tf" = templatefile("${path.module}/config_files/main.tf.tftpl", {
      rke2_module_path = local.rke2_module_path,
      initial          = true
    })
    "./variables.tf" = templatefile("${path.module}/config_files/variables.tf.tftpl", {
      initial = true
    })
    "./outputs.tf" = templatefile("${path.module}/config_files/outputs.tf.tftpl", {
      initial = true
    })
  }
  deploy_path    = join("/", [local.deploy_path, "initial_node"]) # an absolute path where we can implement the config files, needs to be isolated, shouldn't exist
  data_path      = join("/", [local.data_path, "initial_node"])
  deploy_trigger = "v0.0.0"
  environment_variables = { # env variables are inherited, but you can add more here
    TF_PLUGIN_CACHE_DIR = "$HOME/.terraform.d/plugin-cache"
  }
}

module "deploy_other_nodes" {
  depends_on = [
    module.project,
    module.deploy_initial_node,
  ]
  source   = "./modules/deploy"
  for_each = local.other_nodes_info
  inputs   = <<-EOT
    identifier                  = "${local.identifier}"
    email                       = "${local.email}"
    project_domain              = "${local.project_domain}"
    zone                        = "${local.zone}"
    node_info                   = <<-EOD
    ${jsonencode(each.value)}
    EOD
    project_security_group_name = "${module.project.project_security_group.name}"
    image                       = "${local.image}"
    ip_family                   = "${local.ip_family}"
    cloudinit_strategy          = "${local.cloudinit_strategy}"
    k8s_target_group            = "${local.k8s_target_group}"
    runner_ip                   = "${local.runner_ip}"
    username                    = "${local.username}"
    ssh_key                     = "${local.ssh_key}"
    ssh_key_name                = "${local.ssh_key_name}"
    workfolder                  = "${local.workfolder}"
    install_method              = "${local.install_method}"
    download                    = "${local.download}"
    rke2_version                = "${local.rke2_version}"
    install_prep_script         = "${local.install_prep_script}"
    join_token                  = "${module.deploy_initial_node.output.join_token}"
    join_url                    = "${module.deploy_initial_node.output.join_url}"
    cluster_cidr                = "${join(",", module.project.cluster_cidr)}"
    service_cidr                = "${join(",", module.project.service_cidr)}"
  EOT
  template_files = { # map of relative path => absolute path for files that will be copied to the deploy path
    "./versions.tf" = abspath("${path.module}/config_files/versions.tf")
  }
  generated_files = { # map of relative file path to content, the new file will be placed in the deploy path respecting the relative path
    "./main.tf" = templatefile("${path.module}/config_files/main.tf.tftpl", {
      rke2_module_path = local.rke2_module_path,
      initial          = false
    })
    "./variables.tf" = templatefile("${path.module}/config_files/variables.tf.tftpl", {
      initial = false
    })
    "./outputs.tf" = templatefile("${path.module}/config_files/outputs.tf.tftpl", {
      initial = false
    })
  }
  deploy_path    = join("/", [local.deploy_path, each.key]) # an absolute path where we can implement the config files, needs to be isolated, shouldn't exist
  data_path      = join("/", [local.data_path, each.key])
  jitter_min     = 10  # 10 seconds
  jitter_max     = 300 # 5 min
  deploy_trigger = "v0.0.0"
  environment_variables = { # env variables are inherited, but you can add more here
    TF_PLUGIN_CACHE_DIR = "$HOME/.terraform.d/plugin-cache"
  }
}
