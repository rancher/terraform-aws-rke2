provider "aws" {
  default_tags {
    tags = {
      Id    = "${local.identifier}-relay"
      Owner = "terraform-ci@suse.com"
    }
  }
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

locals {
  identifier         = var.identifier
  project_name       = substr("tf-${substr(md5(join("-", [md5(local.identifier)])), 0, 5)}-${local.identifier}", 0, 20)
  username           = lower(local.project_name)
  image              = "sles-15"
  ip                 = chomp(data.http.myip.response_body)
  ssh_key            = var.key
  ssh_key_name       = var.key_name
  fixture            = var.fixture
  fit_dir            = abspath("${path.root}/../../examples/${local.fixture}")
  fit_files          = toset([for f in fileset(local.fit_dir, "*") : f if strcontains(f, ".terraform") != true])
  fit_file_ids       = join("-", [for file in local.fit_files : filemd5("${local.fit_dir}/${file}")])
  module_dir         = abspath("${path.root}/../../")
  module_files       = toset([for f in fileset(local.module_dir, "*") : f if strcontains(f, ".tf")])
  module_file_ids    = join("-", [for file in local.module_files : filemd5("${local.module_dir}/${file}")])
  zone               = var.zone
  rke2_version       = var.rke2_version
  os                 = var.os
  install_method     = var.install_method
  cni                = var.cni
  ip_family          = var.ip_family
  ingress_controller = var.ingress_controller
  home_remote_path   = "/home/${local.username}"
  data_remote_path   = "${local.home_remote_path}/fixture"
  fit_remote_path    = "${local.data_remote_path}/${local.fixture}"
  fit_config_path    = "${local.fit_remote_path}/rke2"
  vars_remote_path   = "${local.fit_remote_path}/inputs.tfvars"
  data_local_path    = abspath("${path.root}/data/${local.identifier}")
  file_path          = local.fit_config_path
  runner_ip          = (local.ip_family == "ipv6" ? module.runner.server.ipv6_addresses[0] : module.runner.server.public_ip)
  cluster_url        = data.external.output.result.api
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
  retry {
    attempts     = 2
    min_delay_ms = 1000
  }
}

resource "local_file" "terraform_vars" {
  content  = <<-EOT
    key_name           = "${chomp(local.ssh_key_name)}"
    key                = "${chomp(local.ssh_key)}"
    identifier         = "${chomp(local.identifier)}"
    zone               = "${chomp(local.zone)}"
    rke2_version       = "${chomp(local.rke2_version)}"
    os                 = "${chomp(local.os)}"
    file_path          = "${chomp(local.file_path)}"
    install_method     = "${chomp(local.install_method)}"
    cni                = "${chomp(local.cni)}"
    ip_family          = "${chomp(local.ip_family)}"
    ingress_controller = "${chomp(local.ingress_controller)}"
    runner_ip          = "${chomp(local.runner_ip)}"
  EOT
  filename = "${local.data_local_path}/vars"
}

module "access" {
  source                     = "rancher/access/aws"
  version                    = "v3.1.5"
  vpc_name                   = "${local.project_name}-vpc"
  vpc_type                   = "dualstack"
  vpc_public                 = true
  security_group_name        = "${local.project_name}-sg"
  security_group_type        = "egress"
  load_balancer_use_strategy = "skip"
  domain_use_strategy        = "skip"
}

module "runner" {
  depends_on = [
    module.access,
  ]
  source                     = "rancher/server/aws"
  version                    = "v1.3.0"
  image_type                 = local.image
  server_name                = local.project_name
  server_type                = "large"
  subnet_name                = keys(module.access.subnets)[0]
  security_group_name        = module.access.security_group.tags_all.Name
  direct_access_use_strategy = "ssh"
  cloudinit_use_strategy     = "default"
  server_access_addresses = {
    "runnerSsh" = {
      port      = 22
      protocol  = "tcp"
      cidrs     = ["${local.ip}/32"]
      ip_family = "ipv4"
    }
    "runnerProxy" = {
      port      = 443
      protocol  = "tcp"
      cidrs     = ["${local.ip}/32"]
      ip_family = "ipv4"
    }
    "runnerKubectl" = {
      port      = 6443
      protocol  = "tcp"
      cidrs     = ["${local.ip}/32"]
      ip_family = "ipv4"
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = "/home/${local.username}"
    timeout                  = 5
  }
}

resource "terraform_data" "install_nix" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
  ]
  triggers_replace = {
    server = module.runner.server.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/install_nix"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      sudo wget https://download.opensuse.org/distribution/leap/15.6/repo/oss/repodata/repomd.xml.key
      sudo rpm --import repomd.xml.key
      sudo zypper ar -f https://download.opensuse.org/distribution/leap/15.6/repo/oss/ leap-oss
      sudo zypper install -y curl
    EOT
    ]
  }
  provisioner "remote-exec" { # install nix
    inline = [<<-EOT
      source /etc/profile || true
      NIX="$(which nix)"
      if [ "" = "$NIX" ]; then
        bash -c "sh <(curl -L https://nixos.org/nix/install) --daemon --yes"
      else
        echo "nix is installed..."
      fi
    EOT
    ]
  }
}

resource "terraform_data" "create_age" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_nix,
  ]
  triggers_replace = {
    server = module.runner.server.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/create_age"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "local-exec" {
    command = <<-EOT
      age-keygen 2>/dev/null | grep -v '^#' > ${local.data_local_path}/age_key
      age-keygen -y ${local.data_local_path}/age_key > ${local.data_local_path}/age_key.pub
      echo "" > ${local.data_local_path}/age_recipients.txt
      cat ${local.data_local_path}/age_key.pub >> ${local.data_local_path}/age_recipients.txt
    EOT
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source /etc/profile || true
      nix-shell -p age --run 'age-keygen 2>/dev/null | grep -v '^#' > age_key'
      nix-shell -p age --run 'age-keygen -y age_key > age_key.pub'
    EOT
    ]
  }
  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no ${local.username}@${module.runner.server.public_ip}:age_key.pub ${local.data_local_path}
    EOT
  }
  provisioner "local-exec" {
    command = <<-EOT
      cat ${local.data_local_path}/age_key.pub >> ${local.data_local_path}/age_recipients.txt
    EOT
  }
  provisioner "local-exec" { # generate encrypted rc file
    command = <<-EOT
      set -e
      echo "" > ${local.data_local_path}/secrets.rc
      for s in $(env | grep 'AWS'); do
        echo "export $s" >> ${local.data_local_path}/secrets.rc
      done
      echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> ${local.data_local_path}/secrets.rc
      echo "export GITHUB_OWNER=$GITHUB_OWNER" >> ${local.data_local_path}/secrets.rc
      echo "export ACME_SERVER_URL=$ACME_SERVER_URL" >> ${local.data_local_path}/secrets.rc
      echo "export IDENTIFIER=$IDENTIFIER" >> ${local.data_local_path}/secrets.rc
      echo "export ZONE=$ZONE" >> ${local.data_local_path}/secrets.rc
      age -e -R ${local.data_local_path}/age_recipients.txt -o "${local.data_local_path}/secrets.rc.age" "${local.data_local_path}/secrets.rc"
      rm -f ${local.data_local_path}/secrets.rc
    EOT
  }
  provisioner "file" { # copy over the encrypted secrets
    source      = "${local.data_local_path}/secrets.rc.age"
    destination = "${local.home_remote_path}/secrets.rc.age"
  }
}

resource "terraform_data" "copy_fixture" {
  for_each = local.fit_files
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.install_nix,
    terraform_data.create_age,
  ]
  triggers_replace = {
    server   = module.runner.server.id
    file_ids = local.fit_file_ids
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_fixture"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      # prevent collisions with random sleep
      sleep $((RANDOM % 7))
      W="$(whoami)"
      echo "I am $W..."

      echo "creating directory ${local.fit_remote_path}..."
      if [ ! -d "${local.fit_remote_path}" ]; then
        sudo install -m 0755 -d "${local.fit_remote_path}"
        sudo chown -R $W:users "${local.fit_remote_path}"
      fi
      ls -lah "${local.fit_remote_path}"

      echo "creating directory ${local.fit_config_path}..."
      if [ ! -d "${local.fit_config_path}" ]; then
        sudo install -m 0755 -d "${local.fit_config_path}"
        sudo chown -R $W:users "${local.fit_remote_path}"
      fi
      ls -lah "${local.fit_config_path}"
    EOT
    ]
  }
  provisioner "file" { # copy the fixture to the remote
    source      = "${local.fit_dir}/${each.key}"
    destination = "${local.fit_remote_path}/${each.key}"
  }
}
resource "terraform_data" "copy_module" {
  for_each = local.module_files
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.install_nix,
    terraform_data.create_age,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
  ]
  triggers_replace = {
    server          = module.runner.server.id
    module_file_ids = local.module_file_ids
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_module"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" {
    source      = "${local.module_dir}/${each.key}"
    destination = "${local.home_remote_path}/${each.key}"
  }
}

resource "terraform_data" "copy_vars" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.install_nix,
    terraform_data.create_age,
    terraform_data.copy_fixture,
  ]
  triggers_replace = {
    input_data = local_file.terraform_vars.content
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "/home/${local.username}/copy_vars"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" { # copy over the variables
    source      = "${local.data_local_path}/vars"
    destination = local.vars_remote_path
  }
}

resource "terraform_data" "copy_command" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
  ]
  triggers_replace = {
    fixtures = md5(jsonencode(terraform_data.copy_fixture[*]))
    vars     = terraform_data.copy_vars.id
    module   = md5(jsonencode(terraform_data.copy_module[*]))
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_command"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" {
    content     = <<-EOT
      set -e
      TF_DIRECTORY="$1"
      export TF_DIRECTORY
      ARGS="$(awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}' <<< "$@")"
      export ARGS
      source /etc/profile || true
      rm -f ${local.home_remote_path}/secrets.rc
      nix-shell -p age --run 'printf "%s" "$(cat ${local.home_remote_path}/age_key)" | age -d -i - -o ${local.home_remote_path}/secrets.rc ${local.home_remote_path}/secrets.rc.age'
      sudo chmod +x ${local.home_remote_path}/secrets.rc
      source ${local.home_remote_path}/secrets.rc
      rm -f ${local.home_remote_path}/secrets.rc
      # secrets are now in the environment
      nix-shell -p tfswitch -p git -p awscli --run ' \
        homebin=${local.home_remote_path}/bin; \
        install -d $homebin; \
        tfswitch -b $homebin/terraform 1.5.7 &>/dev/null; \
        export PATH="$homebin:$PATH"; \
        export TF_IN_AUTOMATION=1; \
        cd $TF_DIRECTORY; \
        terraform $ARGS; \
      '
    EOT
    destination = "${local.fit_remote_path}/terraform_command.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      sudo chmod +x ${local.fit_remote_path}/terraform_command.sh
    EOT
    ]
  }
}

resource "terraform_data" "destroy" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
  ]
  triggers_replace = {
    ip               = module.runner.server.public_ip,
    username         = local.username,
    vars_remote_path = local.vars_remote_path
    fit_remote_path  = local.fit_remote_path
  }
  connection {
    type        = "ssh"
    user        = self.triggers_replace.username
    script_path = "/home/${self.triggers_replace.username}/destroy"
    agent       = true
    host        = self.triggers_replace.ip
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [<<-EOT
      sudo ${self.triggers_replace.fit_remote_path}/terraform_command.sh "${self.triggers_replace.fit_remote_path}" destroy -var-file="${self.triggers_replace.vars_remote_path}" -auto-approve -no-color
    EOT
    ]
  }
}

resource "terraform_data" "apply" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
  ]
  triggers_replace = {
    fixtures = md5(jsonencode(terraform_data.copy_fixture[*]))
    vars     = terraform_data.copy_vars.id
    module   = md5(jsonencode(terraform_data.copy_module[*]))
    cmd      = terraform_data.copy_command.id
    destroy  = terraform_data.destroy.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/apply"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      if [ -z "$GITHUB_TOKEN" ]; then echo "GITHUB_TOKEN isn't set"; else echo "GITHUB_TOKEN is set"; fi
      if [ -z "$GITHUB_OWNER" ]; then echo "GITHUB_OWNER isn't set"; else echo "GITHUB_OWNER is set"; fi
      if [ -z "$ZONE" ]; then echo "ZONE isn't set"; else echo "ZONE is set"; fi
      if [ -z "$CI" ]; then echo "CI isn't set"; else echo "CI is set"; fi
      if [ -z "$IDENTIFIER" ]; then echo "IDENTIFIER isn't set"; else echo "IDENTIFIER is set"; fi
      rm -f "${local.fit_remote_path}/.terraform.lock.hcl"
      ${local.fit_remote_path}/terraform_command.sh "${local.fit_remote_path}" init -upgrade=true
      ${local.fit_remote_path}/terraform_command.sh "${local.fit_remote_path}" apply -var-file="${local.vars_remote_path}" -auto-approve -no-color
    EOT
    ]
  }
}

resource "terraform_data" "output" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
  ]
  triggers_replace = {
    fixtures = md5(jsonencode(terraform_data.copy_fixture[*]))
    vars     = terraform_data.copy_vars.id
    module   = md5(jsonencode(terraform_data.copy_module[*]))
    cmd      = terraform_data.copy_command.id
    destroy  = terraform_data.destroy.id
    apply    = terraform_data.apply.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_output_command"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      ${local.fit_remote_path}/terraform_command.sh "${local.fit_remote_path}" output -json > ${local.fit_remote_path}/output.json
    EOT
    ]
  }
  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no ${local.username}@${module.runner.server.public_ip}:${local.fit_remote_path}/output.json ${local.data_local_path}
    EOT
  }
}

## Set Up the Runner to Proxy Requests From the Testing Server ##

data "external" "output" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
  ]
  program = ["bash", "${path.root}/get_terraform_output.sh"]
  query = {
    data = "${local.data_local_path}/output.json"
  }
}

# create a kubeconfig that points to the proxy
resource "local_file" "kubeconfig" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
  ]
  content  = replace(data.external.output.result.kubeconfig, data.external.output.result.api, "https://${module.runner.server.public_ip}:6443")
  filename = "${local.data_local_path}/kubeconfig"
}

resource "local_file" "k8s_key" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).users[0].user.client-key-data)
  filename = "${local.data_local_path}/k8s.key"
}
resource "local_file" "k8s_cert" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).users[0].user.client-certificate-data)
  filename = "${local.data_local_path}/k8s.crt"
}
resource "local_file" "k8s_ca" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).clusters[0].cluster.certificate-authority-data)
  filename = "${local.data_local_path}/k8s.ca"
}

resource "terraform_data" "copy_certs" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    terraform_data.stop_proxy,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
  ]
  triggers_replace = {
    fixtures = md5(jsonencode(terraform_data.copy_fixture[*]))
    vars     = terraform_data.copy_vars.id
    module   = md5(jsonencode(terraform_data.copy_module[*]))
    cmd      = terraform_data.copy_command.id
    destroy  = terraform_data.destroy.id
    apply    = terraform_data.apply.id
    output   = terraform_data.output.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_certs"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" {
    content     = local_file.k8s_ca.content
    destination = "${local.home_remote_path}/k8s.ca"
  }
  provisioner "file" {
    content     = local_file.k8s_cert.content
    destination = "${local.home_remote_path}/k8s.crt"
  }
  provisioner "file" {
    content     = local_file.k8s_key.content
    destination = "${local.home_remote_path}/k8s.key"
  }
}

resource "terraform_data" "get_cluster_certs" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
  ]
  triggers_replace = {
    kubeconfig = local_file.kubeconfig.content
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/get_cluster_certs"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      if [ "ipv6" = "${local.ip_family}" ]; then
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo cp /var/lib/rancher/rke2/server/tls/server-ca.crt /home/${data.external.output.result.username}/server_ca.crt"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo cp /var/lib/rancher/rke2/server/tls/server-ca.key /home/${data.external.output.result.username}/server_ca.key"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo chown ${data.external.output.result.username} /home/${data.external.output.result.username}/server_ca.crt"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo chown ${data.external.output.result.username} /home/${data.external.output.result.username}/server_ca.key"
        scp -o StrictHostKeyChecking=no ${data.external.output.result.username}@\[${data.external.output.result.server_ip}\]:/home/${data.external.output.result.username}/server_ca.crt ${local.home_remote_path}/server.crt
        scp -o StrictHostKeyChecking=no ${data.external.output.result.username}@\[${data.external.output.result.server_ip}\]:/home/${data.external.output.result.username}/server_ca.key ${local.home_remote_path}/server.key
      else
        # ipv4
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo cp /var/lib/rancher/rke2/server/tls/server-ca.crt /home/${data.external.output.result.username}/server_ca.crt"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo cp /var/lib/rancher/rke2/server/tls/server-ca.key /home/${data.external.output.result.username}/server_ca.key"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo chown ${data.external.output.result.username} /home/${data.external.output.result.username}/server_ca.crt"
        ssh -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip} "sudo chown ${data.external.output.result.username} /home/${data.external.output.result.username}/server_ca.key"
        scp -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip}:/home/${data.external.output.result.username}/server_ca.crt ${local.home_remote_path}/server.crt
        scp -o StrictHostKeyChecking=no ${data.external.output.result.username}@${data.external.output.result.server_ip}:/home/${data.external.output.result.username}/server_ca.key ${local.home_remote_path}/server.key
      fi
    EOT
    ]
  }
}

resource "terraform_data" "stop_proxy" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
    terraform_data.get_cluster_certs,
  ]
  triggers_replace = {
    ip               = module.runner.server.public_ip,
    username         = local.username,
    fixture          = local.fixture,
    input_vars       = local_file.terraform_vars.content
    var_remote_path  = local.vars_remote_path
    data_remote_path = local.data_remote_path
  }
  connection {
    type        = "ssh"
    user        = self.triggers_replace.username
    script_path = "/home/${self.triggers_replace.username}/stop_proxy"
    agent       = true
    host        = self.triggers_replace.ip
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [<<-EOT
      sudo docker stop k8s-proxy
      sudo docker system prune -af || true
      sudo docker ps
    EOT
    ]
  }
}

resource "terraform_data" "proxy" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
    terraform_data.copy_fixture,
    terraform_data.copy_vars,
    terraform_data.copy_module,
    terraform_data.copy_command,
    terraform_data.destroy,
    terraform_data.apply,
    terraform_data.output,
    terraform_data.stop_proxy,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
    terraform_data.get_cluster_certs,
  ]
  triggers_replace = {
    fixtures = md5(jsonencode(terraform_data.copy_fixture[*]))
    vars     = terraform_data.copy_vars.id
    module   = md5(jsonencode(terraform_data.copy_module[*]))
    cmd      = terraform_data.copy_command.id
    destroy  = terraform_data.destroy.id
    apply    = terraform_data.apply.id
    output   = terraform_data.output.id
  }
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/proxy"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" {
    content     = <<-EOT
      set -e
      set -x
      install -d ${local.home_remote_path}/nginx_logs

      cat <<EOF | sudo tee proxy-csr.conf
      [req]
      req_extensions = v3_req
      distinguished_name = req_distinguished_name
      [req_distinguished_name]
      [ v3_req ]
      basicConstraints = CA:FALSE
      keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      subjectAltName = @alt_names
      [alt_names]
      IP.1 = ${module.runner.server.public_ip}
      EOF

      openssl genrsa -out proxy.key 2048
      openssl req -new -key proxy.key -out proxy.csr -config proxy-csr.conf -subj "/CN=${module.runner.server.public_ip}"

      openssl x509 -req -in proxy.csr -CA server.crt -CAkey server.key -CAcreateserial -out proxy.crt -days 365 -extensions v3_req -extfile proxy-csr.conf

      # Create Nginx configuration
      cat <<EOF | sudo tee nginx.conf
      events {}

      http {

        log_format custom '\$remote_addr - "\$request" - \$status - "\$http_host" - \$ssl_client_verify';

        access_log /var/log/nginx/access.log custom;
        error_log /var/log/nginx/error.log debug;

        server {
          listen 6443 ssl;
          listen [::]:6443 ssl;
          ssl_certificate /etc/nginx/proxy.crt;
          ssl_certificate_key /etc/nginx/proxy.key;
          ssl_verify_client off;

          location / {
            proxy_pass ${local.cluster_url};
            proxy_ssl_server_name on;
            proxy_ssl_verify on;
            proxy_ssl_verify_depth 2;
            proxy_ssl_session_reuse on;
            proxy_ssl_certificate /kubeconfig/k8s.crt;
            proxy_ssl_certificate_key /kubeconfig/k8s.key;
            proxy_ssl_trusted_certificate /kubeconfig/k8s.ca;

            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-SSL-Client-Cert \$ssl_client_escaped_cert;
            proxy_set_header X-SSL-Client-Verify \$ssl_client_verify;
          }
        }
      }
      EOF

      # Start Nginx container
      sudo docker run -d --name k8s-proxy \
        --network host \
        -v ${local.home_remote_path}/nginx.conf:/etc/nginx/nginx.conf \
        -v ${local.home_remote_path}/proxy.crt:/etc/nginx/proxy.crt \
        -v ${local.home_remote_path}/proxy.key:/etc/nginx/proxy.key \
        -v ${local.home_remote_path}/nginx_logs:/var/log/nginx \
        -v ${local.home_remote_path}/k8s.ca:/kubeconfig/k8s.ca \
        -v ${local.home_remote_path}/k8s.crt:/kubeconfig/k8s.crt \
        -v ${local.home_remote_path}/k8s.key:/kubeconfig/k8s.key \
        nginx:latest nginx-debug -g 'daemon off;'
    EOT
    destination = "${local.fit_remote_path}/proxy.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      chmod +x ${local.fit_remote_path}/proxy.sh
      ${local.fit_remote_path}/proxy.sh
    EOT
    ]
  }
}
