output "kubeconfig" {
  value     = module.InitialServer.kubeconfig
  sensitive = true
}
