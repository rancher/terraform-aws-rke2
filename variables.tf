# Project Level Variables
variable "project_name" {
  type        = string
  description = <<-EOT
    The name of the project.
    Resources in AWS will be tagged with "Name: <name>-<type>".
    Any resources created will have this name as a prefix in the Name tag.
    This tagging structure is assumed when looking up resources as well.
    We don't rely on "name" attributes(which only exist on a few resources),
    instead only the "Name" tag, which is available on all resources.
  EOT
}

variable "vpc_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy for using VPC resources.
  EOT
  default     = "create"
}

variable "vpc_name" {
  type        = string
  description = <<-EOT
    This variable specifies the name of the VPC to create or select.
  EOT
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = <<-EOT
    This value sets the default private IP space for the created VPC.
  EOT
  default     = ""
}

variable "project_subnet_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy for using subnet resources.
  EOT
  default     = "create"
}

variable "project_subnets" {
  type = map(object({
    cidr              = string,
    availability_zone = string,
    public            = bool,
  }))
  description = <<-EOT
    This variable is a map of subnet objects to create or select.
  EOT
  default = { "default" = {
    cidr              = "",
    availability_zone = "",
    public            = false,
  } }
}

variable "project_security_group_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy for using security group resources.
  EOT
  default     = "create"
}

variable "project_security_group_name" {
  type        = string
  description = <<-EOT
    This variable specifies the name of the EC2 security group to create or select.
  EOT
  default     = ""
}

variable "project_security_group_type" {
  type        = string
  description = <<-EOT
    This variable defines the type of the EC2 security group to create.
  EOT
  default     = "project"
}

variable "project_load_balancer_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy for using load balancer resources.
  EOT
  default     = "create"
}

variable "project_load_balancer_name" {
  type        = string
  description = <<-EOT
    This variable specifies the name of the Load Balancer.
  EOT
  default     = ""
}

variable "project_load_balancer_access_cidrs" {
  type = map(object({
    port     = number
    cidrs    = list(string)
    protocol = string
  }))
  description = <<-EOT
    This variable is a map of access information objects for the Load Balancer.
  EOT
  default     = null
}

variable "project_domain_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy for using domain resources.
  EOT
  default     = "create"
}

variable "project_domain" {
  type        = string
  description = <<-EOT
    This variable specifies the domain name to retrieve or create.
  EOT
  default     = ""
}

variable "project_domain_zone" {
  type        = string
  description = <<-EOT
    This variable defines the domain zone to create.
  EOT
  default     = ""
}

# Server Level Variables
variable "server_image_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy to use for selecting an image.
  EOT
  default     = "find"
}

variable "server_image" {
  type = object({
    id          = string
    user        = string
    admin_group = string
    workfolder  = string
  })
  description = <<-EOT
    This variable is a custom image object used when selecting an image by ID.
  EOT
  default     = null
}

variable "server_image_type" {
  type        = string
  description = <<-EOT
    This variable specifies the designation of server 'image' from the ./image/types.tf file.
  EOT
  default     = ""
}

variable "server_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy to use for selecting a server.
  EOT
  default     = "create"
}

variable "server_id" {
  type        = string
  description = <<-EOT
    This variable specifies the ID of the AWS EC2 instance that you want to select.
  EOT
  default     = ""
}

variable "server_name" {
  type        = string
  description = <<-EOT
    This variable defines the name to give the server.
  EOT
  default     = ""
}

variable "server_type" {
  type        = string
  description = <<-EOT
    This variable specifies the designation of server 'type' from the ./server/types.tf file.
  EOT
  default     = ""
}

variable "server_cloudinit_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy to use for cloud-init.
  EOT
  default     = "skip"
}

variable "server_cloudinit_content" {
  type        = string
  description = <<-EOT
    This variable allows overriding the default cloud-init config.
  EOT
  default     = ""
  sensitive   = true
}

variable "server_private_ip" {
  type        = string
  description = <<-EOT
    This variable specifies an available private IP to assign to the server.
  EOT
  default     = ""
}

variable "server_indirect_access_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy to use for a load balancer.
  EOT
  default     = "skip"
}

variable "server_load_balancer_target_groups" {
  type        = list(string)
  description = <<-EOT
    This variable specifies the names of the target groups to attach the server to.
  EOT
  default     = []
}

variable "server_direct_access_use_strategy" {
  type        = string
  description = <<-EOT
    This variable defines the strategy to use for direct access to the server.
  EOT
  default     = "skip"
}

variable "server_access_addresses" {
  type = map(object({
    port     = number
    cidrs    = list(string)
    protocol = string
  }))
  default     = null
  description = <<-EOT
    This variable is a map of objects with a single port, the CIDRs to allow access to that port, and the protocol to allow for access.
  EOT
}

variable "server_user" {
  type = object({
    user                     = string
    aws_keypair_use_strategy = string
    ssh_key_name             = string
    public_ssh_key           = string
    user_workfolder          = string
    timeout                  = number
  })
  description = <<-EOT
    This variable defines the user configuration for direct SSH access.
  EOT
  default     = null
}

variable "server_add_domain" {
  type        = bool
  description = <<-EOT
    This variable determines whether to add a domain record for the server.
  EOT
  default     = false
}

variable "server_domain_name" {
  type        = string
  description = <<-EOT
    This variable specifies the domain name to use for the server.
  EOT
  default     = ""
}

variable "server_add_eip" {
  type        = bool
  description = <<-EOT
    This variable determines whether to add an Elastic IP to the server.
  EOT
  default     = false
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

# RKE2
variable "rke2_version" {
  type        = string
  description = <<-EOT
    The RKE2 release to install.
    This must match the tag name of the release you would like to install.
  EOT
}
variable "rpm_channel" {
  type        = string
  description = <<-EOT
    The RPM channel for the rke2 version.
    This should be 'stable', 'latest', or 'testing'.
    If left empty, stable will be used.
    Occassionally stable rpms do not exist for the rke2 version,
      this will manifest as a 404 error on the download,
      try setting this to 'latest' in that case.
    If not setting the install_method to "rpm" then this can be ignored.
  EOT
  default     = ""
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
variable "start_timeout" {
  type        = string
  description = <<-EOT
    The number of minutes to wait for rke2 to have status 'active' after enabling service.
    Defaults to 5 minutes, it can be helpful to increase this number if you have custom configs that take a while to enable.
    Especially if the configs require many things to download or if your download speeds are low.
  EOT
  default     = "5"
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
variable "extra_config_content" {
  type        = string
  description = <<-EOT
    Additional config to add to the server.
    Attributes in this content will override the generated initial config by default, this is determined by file name.
    Join token and IP information is optional in this file, it handled by the generated initial config.
    The initial config is designed to handle basic required information, allowing this config to manage other concerns.
    If you have many different configs, consider merging them with terraform's yamlencode function.
    This file will be written to the local_file_path location, changes will overwrite any file there.
  EOT
  default     = ""
}
variable "extra_config_name" {
  type        = string
  description = <<-EOT
    Copy the extra config content to this file name on the node.
    This will get copied to the /etc/rancher/rke2/config.yaml.d directory on the node.
    It is important that this name ends in '.yaml'.
    Files load in ascending order numerically then alphabetically, attributes of files loaded later override.
    The initial generated config is named '50-initial-config.yaml', so the default '51-extra-rke2-config.yaml' loads
      after the initial config and all attributes override it.
    Renaming the file '49-extra-config.yaml' would have the initial generated config override this file.
  EOT
  default     = "51-extra-rke2-config.yaml"
}
