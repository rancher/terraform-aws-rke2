output "kubeconfig" {
  value       = (local.retrieve_kubeconfig ? module.install[0].kubeconfig : "")
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
