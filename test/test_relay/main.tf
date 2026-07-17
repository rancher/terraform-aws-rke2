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

# this is a one shot module, it doesn't need to be designed to have consecutive runs
#   this means we don't need to specify replace triggered by
#   with the exception of destroy time triggered resources
# the orchestrator is better at running Terraform, but it can only run locally
# so we copy the orchestrator over, we copy all the files over, and we execute the orchestrator
# the orchestrator likes to own all of its files, so we stage the fixture in the ~/fixture directory
# the fixture depends on being in a subdirectory of the rke2 module because all of the fixtures implement the rke2 module with source = "../../"
# this means the eventual directory structure that will be run must be /home/user/rke2/fixture/name, eg. /home/${local.username}/rke2/fixture/one
# we have to tell the orchestrator where to put its version of the fixture, and where the fixture is staged locally

locals {
  identifier   = var.identifier
  project_name = substr("tf-${substr(md5(join("-", [md5(local.identifier)])), 0, 5)}-${local.identifier}", 0, 20)
  username     = lower(local.project_name)
  image        = "sles-16"
  ip           = chomp(data.http.myip.response_body)
  ssh_key      = var.key
  ssh_key_name = var.key_name
  fixture      = var.fixture

  # Local Paths
  # path.root will be the test_relay directory
  fixture_local_path = "${path.root}/../../examples/${local.fixture}"
  orchestrator_path  = "${path.root}/orchestrator"
  rke2_module_path   = "${path.root}/../../"
  data_local_path    = abspath("${path.root}/data/${local.identifier}")

  ## Remote Paths
  home_remote_path          = "/home/${local.username}"
  rke2_module_remote_path   = "${local.home_remote_path}/rke2"                          # this is necessary because all of the examples use a path source for the rke2 module
  fixture_instantiated_path = "${local.home_remote_path}/rke2/fixture/${local.fixture}" # the fixture's module's source is "../../"
  fixture_remote_path       = "${local.home_remote_path}/fixture"                       # this is just a temporary staging area, this location won't be executed
  orchestrator_remote_path  = "${local.home_remote_path}/orchestrator"                  # the orchestrator is better at orchestrating
  vars_remote_path          = "${local.orchestrator_remote_path}/inputs.tfvars"         # this is the variables file for the orchestrator

  # Files
  ## Fixture template files (all files from the example fixture)
  fixture_template_files    = [for f in fileset(local.fixture_local_path, "**") : f if !strcontains(f, ".terraform")]
  fixture_template_file_ids = [for file in local.fixture_template_files : "${md5("${local.fixture_local_path}/${file}")}-${filemd5("${local.fixture_local_path}/${file}")}"]
  fixture_template_file_map = {
    for i in range(length(local.fixture_template_file_ids)) :
    local.fixture_template_file_ids[i] => {
      name = basename(local.fixture_template_files[i])
      rel  = dirname(local.fixture_template_files[i])
      src  = "${local.fixture_local_path}/${local.fixture_template_files[i]}"
      dst  = "${local.fixture_remote_path}/${local.fixture_template_files[i]}"
    }
  }
  # example: { abc23 = { name = "versions.tf", path = "/home/user/fixture/versions.tf", src = "./examples/one/versions.tf" }}

  ## Ochestrator files (all files from the orchestrator module)
  # ** is not a blob search, it is unique to thie Terraform function, ** should get files in subdirectories as well
  orchestrator_files    = [for f in fileset(local.orchestrator_path, "**") : f if !strcontains(f, ".terraform")]
  orchestrator_file_ids = [for file in local.orchestrator_files : "${md5("${local.orchestrator_path}/${file}")}-${filemd5("${local.orchestrator_path}/${file}")}"]
  orchestrator_file_map = {
    for i in range(length(local.orchestrator_file_ids)) :
    local.orchestrator_file_ids[i] => {
      name = basename(local.orchestrator_files[i])
      rel  = dirname(local.orchestrator_files[i])
      src  = "${local.orchestrator_path}/${local.orchestrator_files[i]}"
      dst  = "${local.orchestrator_remote_path}/${local.orchestrator_files[i]}"
    }
  }

  # RKE2 root module files (main terraform-aws-rke2 module)
  # The fixture relies on being in a subdirectory of this since the fixture's module source is "../../"
  rke2_module_files    = [for f in fileset(local.rke2_module_path, "*") : f if strcontains(f, ".tf")]
  rke2_module_file_ids = [for file in local.rke2_module_files : "${md5("${local.rke2_module_path}/${file}")}-${filemd5("${local.rke2_module_path}/${file}")}"]
  rke2_module_file_map = {
    for i in range(length(local.rke2_module_file_ids)) :
    local.rke2_module_file_ids[i] => {
      name = basename(local.rke2_module_files[i])
      rel  = dirname(local.rke2_module_files[i])
      src  = "${local.rke2_module_path}/${local.rke2_module_files[i]}"
      dst  = "${local.rke2_module_remote_path}/${local.rke2_module_files[i]}"
    }
  }

  # Variables passed to fixture
  zone           = var.zone
  rke2_version   = var.rke2_version
  os             = var.os
  install_method = var.install_method
  cni            = var.cni
  ip_family      = var.ip_family
  runner_ip      = (local.ip_family == "ipv6" ? module.runner.server.ipv6_addresses[0] : module.runner.server.public_ip)
  cluster_url    = data.external.output.result.api

  # Tool versions
  terraform_version = "1.5.7"
  terraform_sha     = "c0ed7bc32ee52ae255af9982c8c88a7a4c610485cf1d55feeb037eab75fa082c"
  docker_version    = "29.4.1"
  docker_sha        = "0fb3d2b72414ab862d68517f0b17b78c93c149d1c5c461acb969aacde1a2189d"
  age_version       = "1.3.1"
  age_sha           = "bdc69c09cbdd6cf8b1f333d372a1f58247b3a33146406333e30c0f26e8f51377"
  awscli_version    = "2.34.36"
  awscli_sha        = "53aa36a391de63bc0743fa8da7b0517725d3a6415070504063ee5af2c68b0963"
}

check "fixture_provided" {
  assert {
    condition     = local.fixture != ""
    error_message = "A fixture must be provided."
  }
}

check "fit_files_exist" {
  assert {
    condition     = length(local.fixture_template_file_ids) > 0
    error_message = "Fixture template or module files not found in the specified directory."
  }
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
    key_name       = "${chomp(local.ssh_key_name)}"
    key            = "${chomp(local.ssh_key)}"
    identifier     = "${chomp(local.identifier)}"
    zone           = "${chomp(local.zone)}"
    rke2_version   = "${chomp(local.rke2_version)}"
    os             = "${chomp(local.os)}"
    install_method = "${chomp(local.install_method)}"
    cni            = "${chomp(local.cni)}"
    ip_family      = "${chomp(local.ip_family)}"
    runner_ip      = "${chomp(local.runner_ip)}"
    age_key_path   = "${local.home_remote_path}/age_key"
    secrets_path   = "${local.home_remote_path}/secrets.rc.age"
    template_path  = "${local.fixture_remote_path}"
    deploy_path    = "${local.fixture_instantiated_path}"
    data_path      = "${local.fixture_instantiated_path}/data"
    home_path      = "${local.home_remote_path}"
  EOT
  filename = "${local.data_local_path}/vars"
}

module "access" {
  source                     = "rancher/access/aws"
  version                    = "v4.0.2"
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
  version                    = "2.0.3"
  image_type                 = local.image
  server_name                = local.project_name
  server_type                = "xl"
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

resource "terraform_data" "install_dependencies" {
  depends_on = [
    module.access,
    module.runner,
    local_file.terraform_vars,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/install_dependencies"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e

      echo "Installing Age"
      install -d ${local.home_remote_path}/bin

      AGE_VERSION="${local.age_version}"
      AGE_URL="https://github.com/FiloSottile/age/releases/download/v${local.age_version}/age-v${local.age_version}-linux-amd64.tar.gz"
      AGE_SHA256="${local.age_sha}"

      echo "Downloading age..."
      curl -L -o age.tar.gz "$AGE_URL"

      echo "Verifying age checksum..."
      SUM="$(sha256sum age.tar.gz | awk '{print $1}')"
      if [ "$SUM" = "$AGE_SHA256" ]; then 
        echo "Valid!";
      else 
        echo "Invalid!";
        echo "expected: $AGE_SHA256, got: $SUM"
        exit 1;
      fi

      echo "Extracting age..."
      tar xzf age.tar.gz
      mv age/age ${local.home_remote_path}/bin/age
      mv age/age-keygen ${local.home_remote_path}/bin/age-keygen
      chmod +x ${local.home_remote_path}/bin/age ${local.home_remote_path}/bin/age-keygen
      sudo cp ${local.home_remote_path}/bin/age /usr/bin
      sudo cp ${local.home_remote_path}/bin/age-keygen /usr/bin
      rm -rf age age.tar.gz
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e

      install -d ${local.home_remote_path}/bin

      # Install AWS CLI v2 from official bundle
      AWSCLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${local.awscli_version}.zip"

      echo "Downloading AWS CLI..."
      curl -L -o awscliv2.zip "$AWSCLI_URL"

      echo "Verifying checksum..."
      SUM="$(sha256sum awscliv2.zip | awk '{print $1}')"
      if [ "$SUM" = "${local.awscli_sha}" ]; then 
        echo "Valid!";
      else 
        echo "Invalid!";
        echo "expected: ${local.awscli_sha}, got: $SUM"
        exit 1;
      fi

      echo "Extracting AWS CLI..."
      python3 -m zipfile -e awscliv2.zip .
      chmod +x ./aws/install
      sudo ./aws/install -i ${local.home_remote_path}/aws-cli -b ${local.home_remote_path}/bin
      rm -rf awscliv2.zip aws
      sudo chmod +x ${local.home_remote_path}/bin/aws
      sudo cp ${local.home_remote_path}/bin/aws /usr/bin
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e

      install -d ${local.home_remote_path}/bin
      install -d ${local.home_remote_path}/terraform_unpack

      cd ${local.home_remote_path}/terraform_unpack

      FILENAME="terraform_${local.terraform_version}_linux_amd64.zip"

      curl -L -o "$FILENAME" "https://releases.hashicorp.com/terraform/${local.terraform_version}/terraform_${local.terraform_version}_linux_amd64.zip"

      echo "Verifying checksum..."
      SUM="$(sha256sum "$FILENAME" | awk '{print $1}')"
      if [ "$SUM" = "${local.terraform_sha}" ]; then
        echo "Valid!";
      else
        echo "Invalid!";
        echo "expected: ${local.terraform_sha}, got: $SUM"
        exit 1;
      fi

      echo "Unpacking Terraform..."
      python3 -m zipfile -e "$FILENAME" .
      if [ -f terraform ]; then
        mv terraform "${local.home_remote_path}/bin"
        sudo chmod +x "${local.home_remote_path}/bin/terraform"
        sudo cp "${local.home_remote_path}/bin/terraform" /usr/bin
      else
        echo "terraform not found in ${local.home_remote_path}/bin"
        exit 1;
      fi

      rm "$FILENAME"
    EOT
    ]
  }
  # https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04.tar.xz
  provisioner "remote-exec" {
    inline = [<<-EOT
      sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/devel:languages:perl/16.0/devel:languages:perl.repo
      sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/security/16.0/security.repo
      sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/devel:tools:scm/16.0/devel:tools:scm.repo
      sudo zypper --gpg-auto-import-keys refresh
      sudo zypper install -y git
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      DOCKER_VERSION="${local.docker_version}"
      DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz"
      EXPECTED_CHECKSUM="${local.docker_sha}" 

      echo "Downloading Docker v$DOCKER_VERSION..."
      curl -fsSL -o docker.tgz "$DOWNLOAD_URL"

      echo "Verifying checksum..."
      # Extract the first column of the sha256sum output
      ACTUAL_CHECKSUM=$(sha256sum docker.tgz | awk '{print $1}')

      if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
          echo "ERROR: Checksum mismatch!"
          echo "Expected: $EXPECTED_CHECKSUM"
          echo "Actual:   $ACTUAL_CHECKSUM"
          echo "Aborting installation and cleaning up..."
          rm docker.tgz
          exit 1
      fi

      echo "Checksum verified successfully."

      echo "Setting up permissions"
      USER=$(whoami)
      LOG_FILE="/var/log/dockerd.log"

      echo "Starting setup for user: $USER"

      if ! getent group docker > /dev/null 2>&1; then
          sudo groupadd --system docker
          echo "Group 'docker' created."
      fi

      if ! id -u docker > /dev/null 2>&1; then
          sudo useradd --system -g docker -s /bin/false -M docker
          echo "System user 'docker' created."
      fi

      sudo usermod -aG docker "$USER"
      echo "User '$USER' added to 'docker' group."

      if [ ! -f "$LOG_FILE" ]; then
          sudo touch "$LOG_FILE"
      fi
      sudo chown docker:docker "$LOG_FILE"
      sudo chmod 660 "$LOG_FILE"

      echo "Extracting binaries..."
      tar xzvf docker.tgz

      echo "Installing binaries to "${local.home_remote_path}/bin"..."
      sudo chown -R docker:docker docker/
      sudo cp docker/* "${local.home_remote_path}/bin"

      echo "Installing binaries to "/usr/bin"..."
      sudo chown -R docker:docker docker/
      sudo cp docker/* "/usr/bin"
      sudo chmod +x -R "/usr/bin"

      echo "Cleaning up extracted files..."
      sudo rm -rf docker docker.tgz
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      PATH="${local.home_remote_path}/bin:$PATH"

      echo "Starting Docker daemon in the background..."
      # Using nohup prevents the daemon from dying if your SSH session closes.
      # Logs are routed to /var/log/dockerd.log for easy troubleshooting.
      nohup sudo dockerd > /var/log/dockerd.log 2>&1 &
      echo "Waiting for the daemon to initialize..."

      MAX_RETRIES=6
      RETRY_COUNT=0
      SLEEP_TIME=1

      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if sudo docker info > /dev/null 2>&1; then
          echo "Docker daemon is ready!"
          break
        fi
        echo "Docker daemon not ready, waiting $SLEEP_TIME seconds..."
        sleep $SLEEP_TIME
        RETRY_COUNT=$((RETRY_COUNT + 1))
        SLEEP_TIME=$((SLEEP_TIME * 2))
      done

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Docker daemon failed to initialize in time."
        cat /var/log/dockerd.log
        exit 1
      fi

      echo "Testing Docker installation..."
      sudo docker run hello-world
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e
      # Update PATH for current session
      export PATH="${local.home_remote_path}/bin:$PATH"

      # Verify installations
      echo "Verifying installations..."
      echo "git: $(${local.home_remote_path}/bin/git --version)"
      echo "terraform: $(${local.home_remote_path}/bin/terraform -version)"
      echo "age: $(${local.home_remote_path}/bin/age --version)"
      echo "age-keygen: $(${local.home_remote_path}/bin/age-keygen --version)"
      echo "aws: $(${local.home_remote_path}/bin/aws --version)"
      echo "docker: $(${local.home_remote_path}/bin/docker --version)"

      echo "Dependencies installed successfully"
    EOT
    ]
  }
}

resource "terraform_data" "create_age" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/create_age"
    agent       = true
    host        = module.runner.server.public_ip
  }
  # locally create an age key pair for encrypting the secrets file
  provisioner "local-exec" {
    command = <<-EOT
      age-keygen 2>/dev/null | grep -v '^#' > ${local.data_local_path}/age_key
      age-keygen -y ${local.data_local_path}/age_key > ${local.data_local_path}/age_key.pub
      echo "" > ${local.data_local_path}/age_recipients.txt
      cat ${local.data_local_path}/age_key.pub | grep -v -e '^$' > ${local.data_local_path}/age_recipients.txt
    EOT
  }
  # remotely create an age key pair for decrypting the secrets
  provisioner "remote-exec" {
    inline = [<<-EOT
      cd ${local.home_remote_path}
      export PATH="${local.home_remote_path}/bin:$PATH"
      age-keygen 2>/dev/null | grep -v '^#' > age_key
      age-keygen -y age_key > ${local.home_remote_path}/age_key.pub
    EOT
    ]
  }
  # download the remote's public key
  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no ${local.username}@${module.runner.server.public_ip}:${local.home_remote_path}/age_key.pub ${local.data_local_path}
    EOT
  }
  # add remote's public key to the list of recipients
  provisioner "local-exec" {
    command = <<-EOT
      cat ${local.data_local_path}/age_key.pub >> ${local.data_local_path}/age_recipients.txt
      grep -v -e '^$' ${local.data_local_path}/age_recipients.txt > ${local.data_local_path}/new_age_recipients.txt
      mv ${local.data_local_path}/new_age_recipients.txt ${local.data_local_path}/age_recipients.txt
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

resource "terraform_data" "copy_fixture_template" {
  for_each = local.fixture_template_file_map
  depends_on = [
    module.access,
    module.runner,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_fixture_template_${each.key}"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source ~/.bashrc
      # prevent collisions with random sleep
      sleep $((RANDOM % 7))
      W="$(whoami)"

      sudo install -o $W -g users -m 0755 -d ${local.fixture_remote_path}
      sudo install -o $W -g users -m 0755 -d ${local.fixture_remote_path}/${each.value.rel}
    EOT
    ]
  }
  provisioner "file" {
    source      = each.value.src
    destination = each.value.dst
  }
}

resource "terraform_data" "copy_orchestrator" {
  for_each = local.orchestrator_file_map
  depends_on = [
    module.access,
    module.runner,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_orchestrator_${each.key}"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source ~/.bashrc
      # prevent collisions with random sleep
      sleep $((RANDOM % 7))
      W="$(whoami)"

      sudo install -o $W -g users -m 0755 -d "${local.orchestrator_remote_path}"
      sudo install -o $W -g users -m 0755 -d "${local.orchestrator_remote_path}/${each.value.rel}"
    EOT
    ]
  }
  provisioner "file" {
    source      = each.value.src
    destination = each.value.dst
  }
}
resource "terraform_data" "copy_rke2_module" {
  for_each = local.rke2_module_file_map
  depends_on = [
    module.access,
    module.runner,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_rke2_module_${each.key}"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source ~/.bashrc
      # prevent collisions with random sleep
      sleep $((RANDOM % 7))
      W="$(whoami)"

      sudo install -o $W -g users -m 0755 -d "${local.rke2_module_remote_path}"
      sudo install -o $W -g users -m 0755 -d "${local.rke2_module_remote_path}/${each.value.rel}"
    EOT
    ]
  }
  provisioner "file" {
    source      = each.value.src
    destination = each.value.dst
  }
}

resource "terraform_data" "copy_vars" {
  depends_on = [
    module.access,
    module.runner,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "/home/${local.username}/copy_vars"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source ~/.bashrc
      # prevent collisions with random sleep
      sleep $((RANDOM % 7))
      W="$(whoami)"

      sudo install -o $W -g users -m 0755 -d "${dirname(local.vars_remote_path)}"
    EOT
    ]
  }
  provisioner "file" { # copy over the variables
    source      = "${local.data_local_path}/vars"
    destination = local.vars_remote_path
  }
}

resource "terraform_data" "destroy" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
  ]
  triggers_replace = {
    ip                       = module.runner.server.public_ip
    username                 = local.username
    home_path                = local.home_remote_path
    orchestrator_remote_path = local.orchestrator_remote_path
    vars_remote_path         = local.vars_remote_path
  }
  connection {
    type        = "ssh"
    user        = self.triggers_replace.username
    script_path = "${self.triggers_replace.home_path}/destroy"
    agent       = true
    host        = self.triggers_replace.ip
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [<<-EOT
      set -e
      source ~/.bashrc
      export PATH="${self.triggers_replace.home_path}/bin:$PATH"
      export TF_IN_AUTOMATION=1
      export TF_PLUGIN_CACHE_DIR=${self.triggers_replace.home_path}/.terraform.d/plugin-cache
      export AGE_KEY_PATH=${self.triggers_replace.home_path}/age_key
      export AGE_RECIPIENTS_PATH=${self.triggers_replace.home_path}/age_recipients.txt
      export SECRETS_PATH=${self.triggers_replace.home_path}/secrets.rc.age
      cd ${self.triggers_replace.orchestrator_remote_path}
      terraform destroy -var-file="${self.triggers_replace.vars_remote_path}" -auto-approve -no-color -state="tfstate"
    EOT
    ]
  }
}

resource "terraform_data" "apply" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.destroy,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/apply"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      source ~/.bashrc
      export PATH="${local.home_remote_path}/bin:$PATH"
      export TF_IN_AUTOMATION=1
      export TF_PLUGIN_CACHE_DIR=${local.home_remote_path}/.terraform.d/plugin-cache
      export AGE_KEY_PATH=${local.home_remote_path}/age_key
      export AGE_RECIPIENTS_PATH=${local.home_remote_path}/age_recipients.txt
      export SECRETS_PATH=${local.home_remote_path}/secrets.rc.age

      mkdir -p ${local.home_remote_path}/.terraform.d/plugin-cache
      cd ${local.orchestrator_remote_path}
      rm -f .terraform.lock.hcl
      terraform init

      TIMEOUT="120m" # timeout format time before a KILL is sent to the Terraform apply process
      INTERVAL="30" # seconds between attempts
      MAX=3
      EXITCODE=1
      ATTEMPTS=0
      E=1
      E1=0
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; do
        A=0
        while [ $E -gt 0 ] && [ $A -lt "$MAX" ]; do
          timeout -k 1m "$TIMEOUT" terraform apply -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
          E=$?
          if [ $E -eq 124 ]; then echo "Apply timed out after $TIMEOUT"; fi
          A=$((A+1))
        done
        # don't destroy if the last attempt fails
        if [ $E -gt 0 ] && [ $ATTEMPTS != $((MAX-1)) ]; then
          A1=0
          while [ $E1 -gt 0 ] && [ $A1 -lt "$MAX" ]; do
            timeout -k 1m "$TIMEOUT" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
            E1=$?
            if [ $E1 -eq 124 ]; then echo "Apply timed out after $TIMEOUT"; fi
            A1=$((A1+1))
          done
        fi
        if [ $E -gt 0 ]; then
          echo "apply failed..."
        fi
        if [ $E1 -gt 0 ]; then
          echo "destroy failed..."
        fi
        if [ $E -gt 0 ] || [ $E1 -gt 0 ]; then
          EXITCODE=1
        else
          EXITCODE=0
        fi
        ATTEMPTS=$((ATTEMPTS+1))
        if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; then
          echo "wait $INTERVAL seconds between attempts..."
          sleep "$INTERVAL"
        fi
      done
      if [ $ATTEMPTS -eq "$MAX" ]; then echo "max attempts reached..."; fi
      if [ $EXITCODE -ne 0 ]; then echo "failure, exit code $EXITCODE..."; fi
      if [ $EXITCODE -eq 0 ]; then
        echo "success...";
      fi
      exit $EXITCODE
    EOT
    ]
  }
}

resource "terraform_data" "output" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/output"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e
      source ~/.bashrc
      export PATH="${local.home_remote_path}/bin:$PATH"
      export TF_IN_AUTOMATION=1
      export CHECKPOINT_DISABLE=1
      cd ${local.orchestrator_remote_path}
      sudo terraform output -json -state="tfstate" > output.json 2>/dev/null
    EOT
    ]
  }
  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no ${local.username}@${module.runner.server.public_ip}:${local.orchestrator_remote_path}/output.json ${local.data_local_path}
    EOT
  }
}

## Set Up the Runner to Proxy Requests From the Testing Server ##

data "external" "output" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
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
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
  ]
  content  = replace(data.external.output.result.kubeconfig, data.external.output.result.api, "https://${module.runner.server.public_ip}:6443")
  filename = "${local.data_local_path}/kubeconfig"
}

resource "local_file" "k8s_key" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).users[0].user.client-key-data)
  filename = "${local.data_local_path}/k8s.key"
}
resource "local_file" "k8s_cert" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).users[0].user.client-certificate-data)
  filename = "${local.data_local_path}/k8s.crt"
}
resource "local_file" "k8s_ca" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
  ]
  content  = base64decode(yamldecode(data.external.output.result.kubeconfig).clusters[0].cluster.certificate-authority-data)
  filename = "${local.data_local_path}/k8s.ca"
}

resource "terraform_data" "copy_certs" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
  ]
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
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
  ]
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
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
    terraform_data.get_cluster_certs,
  ]
  triggers_replace = {
    username = local.username
    ip       = module.runner.server.public_ip
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
    terraform_data.install_dependencies,
    terraform_data.create_age,
    terraform_data.copy_fixture_template,
    terraform_data.copy_orchestrator,
    terraform_data.copy_rke2_module,
    terraform_data.copy_vars,
    terraform_data.apply,
    terraform_data.output,
    data.external.output,
    local_file.kubeconfig,
    local_file.k8s_cert,
    local_file.k8s_key,
    local_file.k8s_ca,
    terraform_data.get_cluster_certs,
    terraform_data.stop_proxy,
  ]
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
    destination = "${local.home_remote_path}/proxy.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      chmod +x ${local.home_remote_path}/proxy.sh
      ${local.home_remote_path}/proxy.sh
    EOT
    ]
  }
}
