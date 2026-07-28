provider "aws" {
  default_tags {
    tags = {
      Id    = "${local.identifier}-relay"
      Owner = "terraform-ci@suse.com"
    }
  }
}

locals {
  identifier   = var.identifier
  project_name = substr("tf-${substr(md5(join("-", [md5(local.identifier)])), 0, 5)}-${local.identifier}", 0, 20)
  username     = lower(local.project_name)
  image        = var.relay_os
  ip           = chomp(data.http.myip.response_body)
  ssh_key      = var.key
  ssh_key_name = var.key_name

  # Local Paths
  data_local_path = abspath("${path.root}/data/${local.identifier}")

  ## Remote Paths
  home_remote_path = "/home/${local.username}"

  # Tool versions
  docker_version = "29.4.1"
  docker_sha     = "0fb3d2b72414ab862d68517f0b17b78c93c149d1c5c461acb969aacde1a2189d"
  age_version    = "1.3.1"
  age_sha        = "bdc69c09cbdd6cf8b1f333d372a1f58247b3a33146406333e30c0f26e8f51377"
}

check "relay_os_validation" {
  assert {
    condition     = can(regex("^(sles|ubuntu)", local.image))
    error_message = "The test relay OS (image) must be SLES or Ubuntu (e.g. sles-16, ubuntu-24)."
  }
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
  retry {
    attempts     = 2
    min_delay_ms = 1000
  }
}

resource "terraform_data" "create_data_local" {
  provisioner "local-exec" {
    command = "mkdir -p '${local.data_local_path}'"
  }
}

module "access" {
  source                     = "rancher/access/aws"
  version                    = "4.0.5"
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

resource "terraform_data" "copy_repo_archive" {
  depends_on = [
    module.access,
    module.runner,
  ]
  connection {
    type        = "ssh"
    user        = local.username
    script_path = "${local.home_remote_path}/copy_repo_archive"
    agent       = true
    host        = module.runner.server.public_ip
  }
  provisioner "file" {
    source      = var.repo_archive_path
    destination = "/tmp/repo.tar.gz"
  }
}

resource "terraform_data" "install_dependencies" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.copy_repo_archive,
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
      echo "Installing OS package dependencies..."
      if which zypper >/dev/null 2>&1; then
        sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/devel:languages:perl/16.0/devel:languages:perl.repo
        sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/security/16.0/security.repo
        sudo zypper ar --gpgcheck-allow-unsigned https://download.opensuse.org/repositories/devel:tools:scm/16.0/devel:tools:scm.repo
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper install -y git python3 tar curl iptables
      elif which apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y git python3 tar curl iptables
      fi
    EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e
      echo "Unpacking repository archive..."
      mkdir -p ${local.home_remote_path}/workspace
      tar -xzf /tmp/repo.tar.gz -C ${local.home_remote_path}/workspace
      rm -f /tmp/repo.tar.gz
    EOT
    ]
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

      echo "Enabling IPv4 forwarding..."
      sudo sysctl -w net.ipv4.ip_forward=1

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
      echo "Pre-pulling secure Nix CI image..."
      sudo docker pull ghcr.io/rancher/ci-image/nix:20260603-18
    EOT
    ]
  }
}

resource "terraform_data" "create_age" {
  depends_on = [
    module.access,
    module.runner,
    terraform_data.create_data_local,
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
