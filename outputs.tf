output "kubeconfig" {
  value = (
    local.project_mod == 1 && local.server_mod == 1 && local.retrieve_kubeconfig ?
    # Replace the server IP with the domain name
    replace(
      module.install[0].kubeconfig,
      # when replacing the ipv6 server ip, also replace the brackets
      (local.project_vpc_type == "ipv6" ? "[${module.server[0].server.public_ip}]" : module.server[0].server.public_ip),
      "${module.project[0].domain.name}.${local.project_domain_zone}"
    ) :
    # Or do nothing
    ""
  )
  description = <<-EOT
    The kubeconfig for the cluster.
    This replaces the server's public ip with the project's fqdn.
  EOT
  sensitive   = true
}

output "server_kubeconfig" {
  value       = (local.server_mod == 1 && local.retrieve_kubeconfig ? module.install[0].kubeconfig : "")
  description = <<-EOT
    The kubeconfig for the server.
    This kubeconfig has the server's public ip rather than the project domain.
  EOT
  sensitive   = true
}
output "server_rke2_config" {
  value = (
    local.server_mod == 1 && local.project_mod == 1 ?
    (fileexists("${local.local_file_path}/${local.config_default_name}") ? file("${local.local_file_path}/${local.config_default_name}") : null) :
    null
  )
  description = <<-EOT
    The main rke2 config set on the server.
    This will only be set on the initial server which should be deployed with the project.
    That means that this will be null unless both the project and the server are created.
  EOT
}
output "join_url" {
  value = (
    local.config_join_url != "" ? local.config_join_url :
    local.server_ip_family == "ipv6" ? "https://[${module.server[0].server.private_ip}]:9345" :
    "https://${module.server[0].server.private_ip}:9345"
  )
  description = <<-EOT
    The URL to join this cluster.
  EOT
}

output "join_token" {
  value       = local.join_token
  description = <<-EOT
    The token for a server to join this cluster.
  EOT
  sensitive   = true
}

output "cluster_cidr" {
  value       = local.cluster_cidr
  description = <<-EOT
    The CIDR configured for the cluster.
  EOT
}

output "service_cidr" {
  value       = local.service_cidr
  description = <<-EOT
    The CIDR configured for the cluster's services.
  EOT
}

output "project_domain" {
  value       = ((local.project_mod == 1 && local.project_domain_use_strategy != "skip") ? module.project[0].domain.name : "")
  description = <<-EOT
    The domain for the project.
    This is helpful for configuring applications that are exposed indirectly.
  EOT
}

output "project_domain_tls_certificate" {
  value = ((local.project_mod == 1 && local.project_domain_use_strategy != "skip") ?
    module.project[0].certificate :
    {
      id          = ""
      arn         = ""
      name        = ""
      expiration  = ""
      upload_date = ""
      key_id      = ""
      tags_all    = tomap({ "" = "" })
    }
  )
}

output "project_subnets" {
  value = local.project_subnets
}

output "project_load_balancer" {
  value = length(module.project) > 0 ? {
    id              = module.project[0].load_balancer.id
    arn             = module.project[0].load_balancer.arn
    dns_name        = module.project[0].load_balancer.dns_name
    zone_id         = module.project[0].load_balancer.zone_id
    security_groups = module.project[0].load_balancer.security_groups
    subnets         = module.project[0].load_balancer.subnets
    public_ips      = module.project[0].load_balancer.public_ips
    target_groups = [for g in module.project[0].load_balancer_target_groups : {
      id       = g.id
      arn      = g.arn
      name     = g.name
      port     = g.port
      protocol = g.protocol
      tags_all = g.tags_all
    }]
    tags_all = module.project[0].load_balancer.tags_all
  } : null
  description = <<-EOT
    The load balancer object from AWS.
    When generated, this can be helpful to set up indirect access to servers.
    This is a network load balancer with either UDP or TCP protocol.
    As such, it doesn't encrypt or decrypt data and TLS must be handled at the server level.
  EOT
}

output "project_vpc" {
  value = length(module.project) > 0 ? {
    id                  = module.project[0].vpc.id
    ipv4_cidr           = module.project[0].vpc.ipv4_cidr
    ipv6_cidr           = module.project[0].vpc.ipv6_cidr
    main_route_table_id = module.project[0].vpc.main_route_table_id
    tags                = module.project[0].vpc.tags
  } : null
  description = <<-EOT
    The VPC object from AWS.
  EOT
}

output "project_security_group" {
  value = (
    length(module.project) > 0 ?
    {
      id   = module.project[0].security_group.id
      name = module.project[0].security_group.name
    } :
    null
  )
}

output "server_image_id" {
  value = module.server[0].image.id
}
