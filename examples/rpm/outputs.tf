output "kubeconfig" {
  value     = module.aws_rke2_rhel9_rpm.kubeconfig
  sensitive = true
}
