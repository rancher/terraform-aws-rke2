
#####
# Feature: project
# This provides the initial objects necessary to start deploying servers.
#####
variable "project_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using project resources:
      'skip' to disable, or 'create' to generate new project resources.
    A project is not an AWS object, it represents a group of resources in this module.
    The project contains objects which are generally necessary to start deploying infrastructure,
    but only need to be created once, where there will be many more server resources.
    We suggest creating the project resources with the first server and skipping for additional servers.
  EOT
  validation {
    condition     = contains(["skip", "create"], var.project_use_strategy)
    error_message = "The project_use_strategy value must be one of 'skip' or 'create'."
  }
  default = "create"
}

variable "project_name" {
  type        = string
  description = <<-EOT
    A name to give this project.
    This enables the module to set default names for all other objects.
    This is fully optional, but when this is specified the module will generate names for any name field.
    The names will be in the format <project_name>-<resource type>.
    Eg. "myproject-lb" for a loadbalancer, and "myproject-sg" for a security group.
  EOT
  default     = ""
}
variable "project_admin_cidrs" {
  type        = list(string)
  description = <<-EOT
    List of CIDRs to allow access to the project.
    This is only used when no access cidrs are specified and the use strategy indicates they are necessary.
    This is a convenience argument that helps us create default values for several other arguments,
    similar to the project_name argument.
    The arguments this helps populate are: project_load_balancer_access_cidrs and server_access_addresses.
    Those arguments will only be populated if they are empty and necessary.
  EOT
  default     = []
}
variable "project_vpc_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using vpc resources:
      'skip' to disable,
      'select' to use existing,
      or 'create' to generate new vpc resources.
    The default is 'create', which requires a vpc_name and vpc_cidr to be provided.
    When selecting a vpc, the vpc_name must be provided and a vpc that has a tag "Name" with the given name must exist.
    When skipping a vpc, the subnet, security group, and load balancer will also be skipped (automatically).
  EOT
  default     = "create"
  validation {
    condition     = contains(["skip", "select", "create"], var.project_vpc_use_strategy)
    error_message = "The vpc_use_strategy value must be one of 'skip', 'select', or 'create'."
  }
}

variable "project_vpc_name" {
  type        = string
  description = <<-EOT
    This variable specifies the name of the VPC to create or select.
    When the project_name is specified, this will default to <project_name>-vpc.
  EOT
  default     = ""
}

variable "project_vpc_cidr" {
  type        = string
  description = <<-EOT
    This value sets the default private IP space for the created VPC.
    WARNING: AWS reserves the first four IP addresses and the last IP address in any CIDR block for its own use (cumulatively).
    This means that every VPC has 5 IP addresses that cannot be assigned to subnets, and every subnet assigned has 5 IP addresses that cannot be used.
    If you attempt to generate a VPC that has no usable addresses you will get an "invalid CIDR" error from AWS.
    If you attempt to generate a subnet that uses one of the addresses reserved by AWS in the VPC's CIDR, you will get an "invalid CIDR" error from AWS.
  EOT
  default     = "10.0.255.0/24"
}

variable "project_subnet_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using subnet resources:
      'skip' to disable, 'select' to use existing,
      or 'create' to generate new subnet resources.
    The default is 'create', which requires a subnet_name and subnet_cidr to be provided.
    When selecting a subnet, the subnet_name must be provided and a subnet with the tag "Name" with the given name must exist.
    When skipping a subnet, the security group and load balancer will also be skipped (automatically).
  EOT
  default     = "create"
  validation {
    condition     = contains(["skip", "select", "create"], var.project_subnet_use_strategy)
    error_message = "The subnet_use_strategy value must be one of 'skip', 'select', or 'create'."
  }
}

variable "project_subnets" {
  type = map(object({
    cidr              = string,
    availability_zone = string,
    public            = bool,
  }))
  description = <<-EOT
    A map of subnet objects to create or select.
    The key is the name of the subnet, and the value is an object with the following keys:
      cidr: the cidr of the subnet to create
      availability_zone: the availability zone to create the subnet in
      public: set this to true to enable the subnet to have public IP addresses
    WARNING: AWS reserves the first four IP addresses and the last IP address in any CIDR block for its own use (cumulatively).
    This means that every VPC has 5 IP addresses that cannot be assigned to subnets, and every subnet assigned has 5 IP addresses that cannot be used.
    If you attempt to generate a subnet that has no usable addresses you will get an "invalid CIDR" error from AWS.
    If you attempt to generate a subnet that uses one of the addresses reserved by AWS in the VPC's CIDR, you will get an "invalid CIDR" error from AWS.
    When skipping a subnet, the security group and load balancer will also be skipped (automatically).
    When selecting a subnet:
     - the name (key) must be provided and a subnet with the tag "Name" with the given name must exist.
     - the values for cidr, availability_zone, and public will be ignored.
    When creating subnets, any values not supplied will be generated by the module.
     - the name will match the vpc name
     - The availability zone will be whatever the default is for your account.
     - The cidr will be generated based on the VPC's cidr and the number of subnets you are creating.
     - The public flag will be set to false.
    If you are expecting high availability, make sure there are at least three availability zones in the region you are deploying to.
    WARNING! The key for this argument must not be derived from a resource, it must be static.
  EOT
  default = { "default" = {
    cidr              = "", # will be generated based on the vpc cidr
    availability_zone = "", # just get the first one
    public            = false,
  } }
}

variable "project_security_group_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using security group resources:
      'skip' to disable,
      'select' to use existing,
      or 'create' to generate new security group resources.
    The default is 'create'.
    When selecting a security group, the security_group_name must be provided and a security group with the given name must exist.
    When skipping a security group, the load balancer will also be skipped (automatically).
  EOT
  validation {
    condition     = contains(["skip", "select", "create"], var.project_security_group_use_strategy)
    error_message = "The security_group_use_strategy value must be one of 'skip', 'select', or 'create'."
  }
  default = "create"
}

variable "project_security_group_name" {
  type        = string
  description = <<-EOT
    The name of the ec2 security group to create or select.
    When choosing the "create" or "select" strategy, this is required.
    When choosing the "skip" strategy, this is ignored.
    When selecting a security group, the security_group_name must be provided and a security group with the given name must exist.
    When creating a security group, the name will be used to tag the resource, and security_group_type is required.
    The types are located in modules/security_group/types.tf.
    If the project_name is specified this will default to <project_name>-sg.
  EOT
  default     = ""
}

variable "project_security_group_type" {
  type        = string
  description = <<-EOT
    The type of the ec2 security group to create.
    We provide opinionated options for the user to select from.
    Leave this blank if you would like to select a security group rather than generate one.
    The types are located in ./modules/security_group/types.tf.
    If specified, must be one of: project, egress, or public.
  EOT
  validation {
    condition     = contains(["project", "egress", "public"], var.project_security_group_type)
    error_message = "The security_group_type value must be one of 'project', 'egress', or 'public'."
  }
  default = "project"
}

# load balancer
variable "project_load_balancer_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using load balancer resources:
      'skip' to disable,
      'select' to use existing,
      or 'create' to generate new load balancer resources.
    The default is 'create'.
    When selecting a load balancer, the load_balancer_name must be provided and a load balancer with the "Name" tag must exist.
    When skipping a load balancer, the domain will also be skipped (automatically).
  EOT
  default     = "create"
  validation {
    condition     = contains(["skip", "select", "create"], var.project_load_balancer_use_strategy)
    error_message = "The load_balancer_use_strategy value must be one of 'skip', 'select', or 'create'."
  }
}

variable "project_load_balancer_name" {
  type        = string
  description = <<-EOT
    The name of the Load Balancer, there must be a 'Name' tag on it to be found.
    When generating a load balancer, this will be added as a tag to the resource.
    This tag is how we will find it again in the future.
    If a domain and a load balancer name is given, we will create a domain record pointing to the load balancer.
    If the project_name is set, this will default to <project_name>-lb.
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
    A map of access information objects.
    The port is the port to expose on the load balancer.
    The cidrs is a list of external cidr blocks to allow access to the load balancer.
    The protocol is the network protocol to expose on, this can be 'udp' or 'tcp'.
    If the project_admin_cidrs is specified, and the project_load_balancer_use_strategy is not "skip",
     then this will default to allowing the project admin cidrs to access the load balancer on port 443.
    Example:
    {
      test = {
        port = 443
        cidrs = ["1.1.1.1/32"]
        protocol = "tcp"
      }
    }
  EOT
  default     = null
}

# domain
variable "project_domain_use_strategy" {
  type        = string
  description = <<-EOT
    Strategy for using domain resources:
      'skip' to disable,
      'select' to use existing,
      or 'create' to generate new domain resources.
    The default is 'create', which requires a domain name to be provided.
    When selecting a domain, the domain must be provided and a domain with the matching name must exist.
    When adding a domain, it will be attached to all load balancer ports with a certificate for secure access.
  EOT
  validation {
    condition     = contains(["skip", "select", "create"], var.project_domain_use_strategy)
    error_message = "The domain_use_strategy value must be one of 'skip', 'select', or 'create'."
  }
  default = "create"
}

variable "project_domain" {
  type        = string
  description = <<-EOT
    The domain name to retrieve or create.
    Part of creating the domain is assigning it to the load balancer and generating a tls certificate.
    This should enable secure connections for your project.
  EOT
  default     = ""
}

#####
# Feature: server
#####
variable "server_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for selecting a server.
    This can be "create" to create a new server, "select" to select an existing server, or "skip" to do nothing.
    If you choose "select" you must provide the id of the server to select.
    WARNING! No action will be taken and no resources generated by this module when selecting a server,
     all variables except the server_id will be ignored.
    If you select "skip" no server will be created or selected and data will be empty.
  EOT
  default     = "create"
}
variable "server_id" {
  type        = string
  description = <<-EOT
    The id of the AWS Ec2 instance that you want to select.
    This should only be used when you want to select an existing server, and not create a new one.
    This can be helpful if you want to ensure a server exists and get data about it, without managing it.
    This variable is ignored if server_use_strategy isn't "select".
  EOT
  default     = ""
}
variable "server_name" {
  type        = string
  description = <<-EOT
    The name to give the server, this will form the local hostname and appear in the AWS ec2 console.
    The name will be used as the value for the "Name" tag on the server.
    This value is ignored when selecting a server.
    When the project_name argument is set, defaults to <project_name>-server.
  EOT
  default     = ""
}
variable "server_type" {
  type        = string
  description = <<-EOT
    The designation of server "type" from the ./server/types.tf file
    This will set the cpu, ram, and storage resources available to the server.
    Larger types will have higher costs, none of the types listed are in the free tier.
    Current types are "small", "medium", "large", "xl", "xxl"
    Leave this blank when selecting a server.
  EOT
  default     = "small"
}
variable "server_subnet_name" {
  type        = string
  description = <<-EOT
    The name of the AWS subnet that you want to apply to the server.
    Subnets are tied to a specific availability zone, so when you select a subnet you are also selecting an availability zone.
    Defaults to the first subnet supplied in the project_subnets argument.
  EOT
  default     = ""
}
variable "server_security_group_name" {
  type        = string
  description = <<-EOT
    The name of the AWS security group that you want to apply to the server.
    Defaults to the project_security_group_name.
  EOT
  default     = ""
}
variable "server_private_ip" {
  type        = string
  description = <<-EOT
    An available private ip to assign to the server.
    This must be within the subnet assigned to the server.
    If one is not set we will use the next to last ip in the subnet.
  EOT
  default     = ""
}

variable "server_image_use_strategy" {
  description = <<-EOT
    The strategy to use for selecting an image.
    This can be "find" to use our selection of types, "select" to select an image by id, or "skip" to do nothing.
    If you choose "find" you must set the image_type variable.
    If you choose "select" you must set the image variable.
    If you select "skip" no image will be created or selected and data will be empty.
    If you select "skip" dependent resources will be skipped implicitly (including the server mod).
  EOT
  default     = "find"
  validation {
    condition = (
      contains(["find", "select", "skip"], var.server_image_use_strategy)
    )
    error_message = "This must be one of 'find','select', or 'skip'."
  }
}

variable "server_image" {
  type = object({
    id          = string
    user        = string
    admin_group = string
    workfolder  = string
  })
  description = <<-EOT
    Custom image object used when selecting an image by id.
    This variable is required when the image_use_strategy is "select".
    This variable is ignored when the image_use_strategy isn't "select".
    Id attribute is required, the others can be "" unless the 
    direct_access_use_strategy is "ssh".
    The id attribute is the AMS image id.
    The user attribute is the sudo user which already exists on the image.
    The admin_group is the group name for sudo users, eg. "wheel".
    The workfolder is a folder that the user has access to that can execute scripts.
    On most images this can set to "~" to use the user's home directory,
    but on some images (eg. CIS STIG AMIs) a different directory is necessary.
  EOT
  default     = null
}

variable "server_image_type" {
  type = string
  # NOTE: te image list is specific to supported image types for all install types (rpm and tar)
  description = <<-EOT
    The designation of server "image" from the ./image/types.tf file, this relates the AWS AMI information.
    Please be aware that some images require a subscription and will have additional cost over usage of the server.
    Current images are:
        "sles-15",
        "sle-micro-55",
        "rhel-8-cis",
        "ubuntu-20",
        "ubuntu-22",
        "rocky-8",
        "liberty-7",
        "rhel-8",
        "rhel-9"
  EOT
  validation {
    condition = (
      var.server_image_type == "" ? true : contains([
        "sles-15",
        "sle-micro-55",
        "rhel-8-cis",
        "ubuntu-20",
        "ubuntu-22",
        "rocky-8",
        "liberty-7",
        "rhel-8",
        "rhel-9",
      ], var.server_image_type)
    )
    error_message = <<-EOT
      If specified, this must be one of
        "sles-15",
        "sle-micro-55",
        "rhel-8-cis",
        "ubuntu-20",
        "ubuntu-22",
        "rocky-8",
        "liberty-7",
        "rhel-8",
        "rhel-9"
    EOT
  }
  default = "sle-micro-55"
}

variable "server_cloudinit_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for cloudinit, must be one of "skip", "default", or "supply".
    This can be "skip" to skip sending cloudinit, "create" to generate a cloudinit script with defaults,
    or "supply" to specify your own cloudinit content.
    This is ignored when skipping or selecting a server or when direct_access_use_strategy isn't "ssh".
  EOT
  validation {
    condition = (
      var.server_cloudinit_use_strategy == "" ? true : contains(["skip", "default", "supply"], var.server_cloudinit_use_strategy)
    )
    error_message = "If specified, this must be one of 'skip', 'default', or 'supply'."
  }
  default = "skip"
}

variable "server_cloudinit_content" {
  type        = string
  description = <<-EOT
    This is a yaml formatted string that will be sent as base64 encoded "user-data" to the EC2 api when creating the server.
    This should be raw text, the module will handle the base64 encoding.
    WARNING!! Some OS configurations prevent cloud-init from writing files, such as STIG CIS AMIs.
  EOT
  default     = ""
  sensitive   = true
}


#####
# Feature: indirect access (network load balancer support)
#####
variable "server_indirect_access_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for a load balancer.
    This can be "enable" to select an existing load balancer, or "skip" to do nothing.
    If you choose "enable" you must provide the name of the load balancer to select in the load_balancer_name variable.
    If you choose "skip" no load balancer will be created or selected and data will be empty.
  EOT
  validation {
    condition = (
      contains(["enable", "skip"], var.server_indirect_access_use_strategy)
    )
    error_message = "This must be one of 'enable' or 'skip'."
  }
  default = "enable"
}

variable "server_load_balancer_target_groups" {
  type        = list(string)
  description = <<-EOT
    The names of the target groups to attach the server to.
    This must be a list of strings, each string is the name of a target group.
    This is only used if indirect_access_use_strategy is set to "enable".
    The target_group must have a tag "Name" with this exact value.
    Defaults to <project_load_balancer_name>-<first project_load_balancer_access_cidrs key>.
    eg. ["myproject-lb-ping"] where the load balancer name is myproject-lb, and the first access cidr key is 'ping'.
  EOT
  default     = []
}

#####
# Feature: direct node access
#####
# Options here are for direct access to the server from outside the VPC
#   this is not recommended for production servers.
# Instead, use this to create prototypes which you can snapshot and deploy
#  in production environments without outside access.
# Skipping this will disable the install feature automatically.
#   without direct access the installer can't work.
variable "server_direct_access_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for direct access to the server.
    This can be "network", "ssh", or "skip".
    If you choose 'skip' nothing will be done and server_access_addresses, server_user, ssh_key_content, domain, and eip variables will be ignored.
    If you choose "network" only network level access will be created, and server_access_addresses is required.
    If you choose "ssh", then network level access will be created as well as ssh access.
    To enable ssh access we connect to the server over ssh and run scripts which remove the default user, add a new user, 
    and add the specified public ssh key to the new user. The server_user variable is required.
    Optionally, you may add a domain name or an elastic ip to your server with the add_eip and add_domain variables.
  EOT
  validation {
    condition = (
      contains(["network", "ssh", "skip"], var.server_direct_access_use_strategy)
    )
    error_message = "This must be one of 'network', 'ssh', or 'skip'."
  }
  default = "ssh"
}

variable "server_access_addresses" {
  type = map(object({
    port     = number
    cidrs    = list(string)
    protocol = string
  }))
  description = <<-EOT
    A map of objects with a single port, the cidrs to allow access to that port,
    and the protocol to allow for access.
    The port is the tcp port number to expose. eg. 80
    The cidrs is a list of cidrs to allow to that port. eg ["1.1.1.1/32","2.2.2.2/24"]
    The protocol is the tranfer protocol to allow, usually "tcp" or "udp".
    If the project_admin_cidrs is specified, and server_direct_access_use_strategy is not "skip",
     then this will default to allowing the project admin cidrs to access the servers on port 22 and 6443.
    Example:
      {
        workstation = {
          port = 443,
          cidrs = ["100.1.1.1/32"],
          protocol = "tcp"
        }
        ci = {
          port = 443
          cidrs = ["50.1.1.1/32"],
          protocol = "tcp"
        }
      }
  EOT
  default     = null
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
    This is required if direct_access_use_strategy is "ssh".
    The user specified will be added to the server with passwordless sudo access.
    The public_ssh_key will be added to the /home/<user>/.ssh/authorized_keys file.
    The timeout value is the number of minutes to wait for setup to complete, defaults to 5.
    Some images must have an ssh key passed to the cloud provider when generating the server (CIS STIG),
    to enable this set the aws_keypair_use_strategy to either "select" or "create".
    Select will select the ssh key with the name attribute equal to the "ssh_key_name" specified.
    Create will create a new ssh key with the given name and public ssh key. (ssh keypair objects can't have tags).
  EOT
  validation {
    condition = (
      var.server_user == null ? true : (length(var.server_user["user"]) <= 32 ? true : false)
    )
    error_message = "If specified, user must be 32 characters or less."
  }
  default = null
}

variable "server_add_domain" {
  type        = bool
  description = <<-EOT
    When this is true domain_name and domain_zone is required.
    This will add a record with the server's public IP address to route53.
    You must already have a zone setup and configured properly for this to work.
  EOT
  default     = false
}

variable "server_domain_name" {
  type        = string
  description = <<-EOT
    The domain name to use for the server.
    The zone for this domain must already exist in route53.
  EOT
  default     = ""
}

variable "server_domain_zone" {
  type        = string
  description = <<-EOT
    The domain zone to place the server domain in.
    The zone must already exist in route53 and be routable.
  EOT
  default     = ""
}

variable "server_add_eip" {
  type        = bool
  description = <<-EOT
    Set this to true to add an elastic IP to the server.
    WARNING! By default, all AWS accounts have a quota of five (5) Elastic IP addresses per Region.
    You can change this in your account quota settings.
    Some programs (such as kubernetes) require the IP on the primary interface to remain stable,
      this can be achieved by specifying the private_ip variable rather than using an elastic IP.
  EOT
  default     = false
}

#####
# Feature: install
#####
variable "install_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use to install rke2 on the server.
    https://github.com/rancher/rke2/blob/master/install.sh
    Options are 'skip', 'rpm', 'tar'.
    Choose 'skip' to disable install, generally only used in testing,
      but maybe useful when deploying immutable infrastructure.
    Choose 'rpm' to run the installer with default settings,
      downloading from our public RPM repositories
      and installing using the package manager on the server.
      Please make sure that we support your package manager before choosing this option.
    Choose 'tar' to install using the 'tarball' method,
      this requires the local_file_use_strategy not to be skipped.
      The 'tar' method will take files in the local_file_path,
        copy them over to the server and install them without downloading from the internet.
        This approach is appropriate for air-gapped projects.
  EOT
  validation {
    condition = (
      contains(["skip", "rpm", "tar"], var.install_use_strategy)
    )
    error_message = "This must be one of 'skip', 'rpm', or 'tar'."
  }
  default = "rpm"
}
variable "local_file_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for staging files locally (on the runner).
    This can be "download" to download files from a GitHub release,
    "supply" to add files outside of this module, or "skip" to only store the configs.
    Choose supply to supply your own files,
      they must be named appropriately for the installer to recognize them.
    Choose download and the module will attempt to download the
      files from the release specified in the rke2_version argument.
    What you choose here has a big effect on how rke2 is installed,
      please see install_use_strategy for more information.
  EOT
  validation {
    condition = (
      contains(["skip", "supply", "download"], var.local_file_use_strategy)
    )
    error_message = "This must be one of 'skip', 'supply', or 'download'."
  }
  default = "download"
}
variable "local_file_path" {
  type        = string
  description = <<-EOT
    A local file path where the RKE2 release and configuation files can be found or should be downloaded to.
    This must be a full path, relative paths will cause hard to fix errors.
    This should exist on the server running Terraform.
    WARNING! This needs to be an isolated directory,
    the module will fail if files that are not pertinent to this install are present.
    Don't use the same directory as other releases or configurations.
    Defaults to the root module's directory + rke2.
    eg. path/to/root/module/rke2
  EOT
  default     = ""
}
variable "install_rke2_version" {
  type        = string
  description = <<-EOT
    The RKE2 release to install.
    This must match the tag name of the release you would like to install.
  EOT
  validation {
    condition = (
      var.install_rke2_version == "" ? true :
      (can(regex("^v[[:digit:]]{1}\\.[[:digit:]]{1,2}\\.[[:digit:]]{1,2}(?:-rc[[:digit:]]{1,2})?\\+rke2r[[:digit:]]{1}$", var.install_rke2_version)) ? true : false)
    )
    error_message = "If specified, version must match tag format eg. v1.29.4+rke2r1 or optionally v1.29.4-rc1+rke2r1"
  }
  default = ""
}
variable "install_rpm_channel" {
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
  validation {
    condition = (
      contains(["", "stable", "latest", "testing"], var.install_rpm_channel)
    )
    error_message = "If set, this must be one of 'stable', 'latest', or 'testing'."
  }
  default = "stable"
}
variable "install_remote_file_path" {
  type        = string
  description = <<-EOT
    The remote file path where the RKE2 release and configuation files can be found or should be placed.
    This defaults to "/home/<ssh_username>/rke2".
    You should only change this if your OS has special restrictions for execution.
  EOT
  default     = ""
}
variable "install_prep_script" {
  type        = string
  description = <<-EOT
    The contents of a script to run on the server before installing RKE2.
    This is helpful when you need to install packages or configure the server before installing RKE2.
    Such as installing selinux policies before using the rpm install method.
    This script will be run as root.
  EOT
  default     = ""
}
variable "install_start_prep_script" {
  type        = string
  description = <<-EOT
    The contents of a script to run on the server before starting RKE2.
    This is helpful when you need to install packages or configure the server before running RKE2.
    This script will be run as root.
    This can help mitigate issues like those found here: https://docs.rke2.io/known_issues#networkmanager
  EOT
  default     = ""
}
variable "install_role" {
  type        = string
  description = <<-EOT
    The role of the server.
    The current options are: "server" and "agent".
    This is used by the RKE2 installer to start the correct services.
    https://github.com/rancher/rke2/blob/master/install.sh#L25
  EOT
  default     = "server"
}
variable "install_start" {
  type        = bool
  description = <<-EOT
    Set this to false if you want to install rke2 without starting it.
    The install_prep_script will be run after install, then the module will stop.
  EOT
  default     = true
}
variable "install_start_timeout" {
  type        = string
  description = <<-EOT
    The number of minutes to wait for rke2 to have status 'active' after enabling service.
    Defaults to 5 minutes, it can be helpful to increase this number if you have custom configs that take a while to enable.
    Especially if the configs require many things to download or if your download speeds are low.
  EOT
  default     = "5"
}

#####
# Feature: configure
#####
variable "config_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for configuring rke2.
    Can be 'skip', 'default', 'supply', or 'merge'.
    Choose skip if you don't want to send a config.
    Choose 'default' to allow the module to configure the base items necessary for clustering.
    Choose 'supply' to send your own config, and disable the default config.
    Choose 'merge' to enable the default config, but override some items with a supplied config.
  EOT
  default     = "default"
}
variable "config_default_name" {
  type        = string
  description = <<-EOT
    The name for the generated config.
    The default config will be generated with a random join token and will communicate all of the required information to join nodes together.
    This config will be written locally in the local_file_path, and copied to the /etc/rancher/rke2/config.yaml.d directory on the node.
    Please see https://docs.rke2.io/install/configuration#multiple-config-files for more information.
  EOT
  default     = "50-default-config.yaml"
}
variable "config_supplied_content" {
  type        = string
  description = <<-EOT
    The config contents to use.
    This us only used when config_use_strategy is 'supply' or 'merge'.
  EOT
  default     = ""
}
variable "config_supplied_name" {
  type        = string
  description = <<-EOT
    The name for the config supplied in the config_content argument.
    This config will be written locally in the local_file_path, and copied to the /etc/rancher/rke2/config.yaml.d directory on the node.
    It is important that this name ends in '.yaml'.
    Files load in ascending order numerically then alphabetically, attributes of files loaded later override.
    The default config is named '50-default-config.yaml' by default, so the default '51-rke2-config.yaml' loads
      after the initial config and all attributes override it.
    Naming this '49-rke2-config.yaml' would have the default config override this one.
    Please see https://docs.rke2.io/install/configuration#multiple-config-files for more information.
  EOT
  default     = "51-rke2-config.yaml"
}
variable "config_join_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for joining nodes.
    Can be 'skip' or 'join'.
    When joining, please supply the config_join_token and config_join_url.
    If the install_role is 'agent' this will be automatically set to 'join'.
  EOT
  default     = "skip"
}
variable "config_join_url" {
  type        = string
  description = <<-EOT
    When config_use_strategy is 'default' or 'merge',
    if this is set, a line will be added to the config pointing to this server as the server to join.
    If this isn't set then the server url will not be set automatically in the config and it will start a new cluster.
    example value: https://192.168.0.1:9345 or https://initial.server.domain:9345
  EOT
  default     = ""
}
variable "config_join_token" {
  type        = string
  description = <<-EOT
    When config_use_strategy is 'default' or 'merge',
    if this is set, a line will be added to the config with this join token.
    If this isn't set, then a line will be added to the config with a random join token.
    It is important for this to be the same for all servers in a cluster.
  EOT
  default     = ""
}
# variable "config_agent_join_token" {
#   type        = string
#   description = <<-EOT
#     When config_use_strategy is 'default' or 'merge',
#     if this is set, a line will be added to the config with this join token.
#     If this isn't set, then a line will be added to the config with a random join token.
#     It is important for this to be the same for all servers in a cluster.
#   EOT
#   default     = ""
# }

#####
# Feature: retrieve kubeconfig
#####
variable "retrieve_kubeconfig" {
  type        = bool
  description = <<-EOT
    A boolean value to retrieve the kubeconfig from the server.
    This is useful when the kubeconfig is needed to interact with the cluster in further steps.
  EOT
  default     = true
}
