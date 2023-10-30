# general
variable "name" {
  type        = string
  description = <<-EOT
    The name of the project.
    Resources in AWS will be tagged with "Name: <name>".
    Any resources created will have this name as a tag.
    This tagging structure is assumed when looking up resources as well.
    We don't rely on "name" attributes(which only exist on a few resources),
    instead only the "Name" tag, which is available on all resources.
  EOT
}
variable "owner" {
  type        = string
  description = <<-EOT
    The email address of the person responsible for the infrastructure. 
    Resources in AWS will be tagged with "Owner: <owner>".
    This is helpful when multiple people are using the same AWS account.
    We recommend using an email address,
    or some identifier that can be used to contact the owner.
  EOT
}
# access variables
variable "vpc_name" {
  type        = string
  description = <<-EOT
    The name of the VPC to use.
    To generate a new VPC, set this and the vpc_cidr variable.
  EOT
}
variable "vpc_cidr" {
  type        = string
  description = <<-EOT
    Setting this tells the module to create a new VPC.
    The cidr to give the new VPC.
    If you just want to select a vpc that already exists, ignore this.
  EOT
  default     = ""
}
variable "subnet_name" {
  type        = string
  description = <<-EOT
    The name of the subnet to use.
    To generate a new subnet, set this and the subnet_cidr variable.
  EOT
}
variable "subnet_cidr" {
  type        = string
  description = <<-EOT
    Setting this tells the module to create a new subnet.
    The cidr to give the new subnet, must be within the vpc cidr.
    If you just want to select a subnet that already exists, ignore this.
  EOT
  default     = ""
}
variable "security_group_name" {
  type        = string
  description = <<-EOT
    The name of the security group to use.
    To generate a new security group, set this and the security_group_type variable.
  EOT
}
variable "security_group_type" {
  type        = string
  description = <<-EOT
    The type of security group to create.
    This is one of the preconfigured types provided by our terraform-aws-access module.
    The options can be found here:
    https://github.com/rancher/terraform-aws-access/blob/main/modules/security_group/types.tf
    Setting this tells the module to create a new security group.
    If you just want to select a security group that already exists, ignore this.
  EOT
  default     = ""
}
variable "security_group_ip" {
  type        = string
  description = <<-EOT
    The public IP address of the server running Terraform.
    Security groups will be generated allowing this IP to access the servers.
    If this is not set, the module will attempt to discover it.
  EOT
  default     = ""
}
variable "ssh_username" {
  type        = string
  description = <<-EOT
    The username to use when connecting to the server.
    This user will be generated on the server, and will have password-less sudo access.
    We recommend restricing this user as much as possible.
    The 32 character limit is due to using useradd to create the user.
  EOT
  validation {
    condition = (
      length(var.ssh_username) <= 32 ? true : false
    )
    error_message = "Username has a maximum of 32 characters."
  }
}
variable "ssh_key_name" {
  type        = string
  description = <<-EOT
    The name of the ssh key resource in AWS to use.
    To generate a new ssh key resource, set this and the ssh_key_content variable.
    Generating an ssh key resource isn't the same as generating a new ssh keypair.
  EOT
}
variable "ssh_key_content" {
  type        = string
  description = <<-EOT
    The content of the public ssh key to use.
    If this is set, a new ssh key resource will be generated in AWS.
    Generating an ssh key resource isn't the same as generating a new ssh keypair.
    The user should generate their own ssh keypair, and provide the public key to this module.
    If you just want to select an ssh_key that already exists, ignore this.
  EOT
  default     = ""
}
# server
variable "server_type" {
  type        = string
  description = <<-EOT
    The type of server to create.
    This is one of the preconfigured types provided by our terraform-aws-server module.
    The options can be found here:
    https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
    WARNING: the larger the server, the more it will cost.
  EOT
  default     = "large"
}
variable "availability_zone" {
  type        = string
  description = <<-EOT
    The availability zone to use when creating the subnet.
    The value of this will depend on the region you are deploying to and the VPC.
    This is only used when creating a new subnet.
    If this is not set, the default availability zone for the region will be used.
    This guide can help you find the correct value for your region and VPC:
    [AWS AZ Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#availability-zones-describe)
    Deploying servers in the same availability zone will improve connection speeds between them.
    Deploying servers in different availability zones will improve availability.
    Use the zone "Name" not the zone "Id".
  EOT
  default     = ""
}
variable "image_type" {
  type        = string
  description = <<-EOT
    The type of image to use.
    This is one of the preconfigured types provided by our terraform-aws-server module.
    The options can be found here:
    https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
    WARNING: some image types require subscription
  EOT
  default     = "sles-15"
}
# download
variable "skip_download" {
  type        = bool
  description = <<-EOT
    A boolean value to skip downloading the RKE2 binary files.
    This is useful when using the "rpm" installation method, or when you are downloading the files manually.
  EOT
  default     = false
}
variable "local_file_path" {
  type        = string
  description = <<-EOT
    A local file path where the RKE2 release and configuation files can be found or should be downloaded to.
    This must be a full path, relative paths will cause hard to fix errors.
    This should exist on the server running Terraform.
    If this isn't set, the module will assume the files are already on the server at the remote_file_path.
    WARNING: If this variable isn't set, Terraform can't track changes to the files.
  EOT
  default     = ""
}

# rke2
variable "rke2_version" {
  type        = string
  description = <<-EOT
    The RKE2 release to install.
    This must match the tag name of the release you would like to install.
  EOT
}
variable "remote_file_path" {
  type        = string
  description = <<-EOT
    The remote file path where the RKE2 release and configuation files can be found or should be placed.
    This defaults to "/home/<ssh_username>/rke2".
    You should only change this if your OS has special restrictions for execution.
  EOT
  default     = ""
}
variable "join_token" {
  type        = string
  sensitive   = true
  description = <<-EOT
    The token to use when joining the server to a cluster.
    This is expected even when deploying a single server.
    This allows the user to deploy a single server
    and then add more servers later without changing the first server.
  EOT
}
variable "join_url" {
  type        = string
  description = <<-EOT
    The url of the registration endpoint on the first control plane server.
    This should be null on the first server, outputs from the first server include this value to use as input for others.
  EOT
  default     = null
}
variable "role" {
  type        = string
  description = <<-EOT
    The role of the server.
    The current options are: "server" and "agent".
    This is used by the RKE2 installer to start the correct services.
    https://github.com/rancher/rke2/blob/master/install.sh#L25
  EOT
  default     = "server"
}
variable "retrieve_kubeconfig" {
  type        = bool
  description = <<-EOT
    A boolean value to retrieve the kubeconfig from the server.
    This is useful when the kubeconfig is needed to interact with the cluster.
  EOT
  default     = false
}
variable "install_method" {
  type        = string
  description = <<-EOT
    The method to use when installing RKE2.
    The current options are: "tar" and "rpm".
    https://github.com/rancher/rke2/blob/master/install.sh#L21
  EOT
  default     = "tar"
}
variable "server_prep_script" {
  type        = string
  description = <<-EOT
    The contents of a script to run on the server before running RKE2.
    This is helpful when you need to install packages or configure the server before running RKE2.
    This script will be run as root.
    This can help mitigate issues like those found here: https://docs.rke2.io/known_issues#networkmanager
  EOT
  default     = ""
}
variable "start" {
  type        = bool
  description = <<-EOT
    Set this to false if you want to install rke2 without starting it.
    The server_prep_script will be run after install, then the module will stop.
  EOT
  default     = true
}
variable "initial_config_name" {
  type        = string
  description = <<-EOT
    The name for the initially generated config.
    The initial config will be generated with a random join token and will communicate all of the required information to join nodes together.
    This config will be written locally in the local_file_path, and copied to the config.d directory on the node.
    Please see https://docs.rke2.io/install/configuration#multiple-config-files for more information.
  EOT
  default     = "50-initial-generated-config.yaml"
}
