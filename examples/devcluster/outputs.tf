output "kubeconfig" {
  value     = module.TestInitialServer.kubeconfig
  sensitive = true
}
