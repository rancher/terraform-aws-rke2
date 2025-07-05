# Example Single Node Cluster

This example demonstrates how to deploy a single-node RKE2 cluster on AWS using Terraform. Perfect for development, testing, learning, and proof-of-concept deployments.

## Overview

This configuration creates a minimal RKE2 cluster with:
- **Single Control Plane Node**: Combined control plane and worker functionality
- **Minimal AWS Resources**: Cost-effective for development and testing
- **Quick Deployment**: Fast setup and teardown for iterative development
- **Full RKE2 Features**: Complete Kubernetes functionality in a single node

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Single Node Architecture                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Single Node                            │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │ Control Plane + Worker                      │   │   │
│  │  │ • API Server                                │   │   │
│  │  │ • etcd                                      │   │   │
│  │  │ • Scheduler                                 │   │   │
│  │  │ • Controller Manager                        │   │   │
│  │  │ • Kubelet                                   │   │   │
│  │  │ • Container Runtime                         │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              AWS Resources                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ EC2 Instance│  │ VPC &       │  │ Security    │  │   │
│  │  │ (t3.medium) │  │ Subnets     │  │ Groups      │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### **Development & Testing**
- **Quick Setup**: Deploy in minutes for rapid iteration
- **Cost Effective**: Minimal AWS resources and costs
- **Full Functionality**: Complete Kubernetes features
- **Easy Cleanup**: Simple teardown for testing cycles

### **Learning & Experimentation**
- **Complete Control**: All components on one node
- **Easy Debugging**: Single point of troubleshooting
- **Customization**: Full control over configuration
- **Educational**: Understand RKE2 architecture

### **Proof of Concept**
- **Rapid Prototyping**: Test ideas quickly
- **Feature Validation**: Verify configurations before scaling
- **Integration Testing**: Test with external services
- **Performance Testing**: Baseline performance measurements

## Use Cases

### **Development Environment**
- Local development with production-like environment
- Testing application deployments
- Validating Helm charts and manifests
- CI/CD pipeline testing

### **Learning Kubernetes**
- Understanding RKE2 architecture
- Learning Kubernetes concepts
- Experimenting with configurations
- Debugging and troubleshooting

### **Proof of Concept**
- Validating application architecture
- Testing new features or configurations
- Demonstrating capabilities to stakeholders
- Performance and scalability testing

## Requirements

### **Prerequisites**
- Terraform (v1.5.7+)
- AWS CLI configured with appropriate permissions
- SSH key pair for node access
- Basic understanding of RKE2 and Kubernetes

### **External Tools**
- shell (bash)
- chmod, cat, install, scp, sed
- kubectl (for cluster interaction)

### **Optional Tools**
- [Nix](https://nixos.org/) for dependency management (see flake.nix in repo root)

## Usage

### **Quick Start**
1. **Clone and navigate**:
   ```bash
   cd examples/one
   ```

2. **Configure variables**:
   ```bash
   # Copy and edit variables
   cp variables.tf terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy the cluster**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access the cluster**:
   ```bash
   # Get kubeconfig
   terraform output -raw kubeconfig > kubeconfig.yaml
   
   # Use kubectl
   kubectl --kubeconfig kubeconfig.yaml get nodes
   ```

### **Configuration Options**

#### **Instance Type**
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"  # Good for development
}
```

#### **RKE2 Version**
```hcl
variable "rke2_version" {
  description = "RKE2 version to install"
  default     = "v1.28.0+rke2r1"
}
```

#### **Networking**
```hcl
variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}
```

## Important Notes

### **Single Point of Failure**
⚠️ **This is NOT for production use!**
- Single node means no high availability
- Node failure = complete cluster outage
- No automatic failover or recovery

### **Resource Limitations**
- Limited by single instance capacity
- No horizontal scaling capabilities
- Performance constrained by instance type

### **Security Considerations**
- Single node reduces attack surface but increases risk
- All components on one node
- Consider security groups and network policies carefully

## Post-Deployment

### **Verify Cluster Health**
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get componentstatuses
```

### **Install CNI**
Choose your preferred CNI:
```bash
# Calico
kubectl apply -f calico.yaml

# Cilium
kubectl apply -f cilium.yaml
```

### **Access Rancher (Optional)**
If you want to use Rancher for management:
```bash
# Install Rancher
kubectl apply -f https://github.com/rancher/rancher/releases/download/v2.7.0/rancher.yaml
```

## Troubleshooting

### **Common Issues**

**Node Not Ready**
- Check instance health and SSH access
- Verify security group rules
- Review RKE2 logs: `journalctl -u rke2-server`

**Pod Scheduling Issues**
- Ensure CNI is installed
- Check node resources and capacity
- Verify taints and tolerations

**Network Connectivity**
- Verify VPC and subnet configuration
- Check security group rules
- Ensure proper routing

### **Debugging Commands**
```bash
# Check RKE2 status
sudo systemctl status rke2-server

# View RKE2 logs
sudo journalctl -u rke2-server -f

# Check node resources
kubectl describe node <node-name>

# Verify cluster components
kubectl get componentstatuses
```

## Cost Optimization

### **Development Costs**
- Use `t3.medium` or `t3.small` for development
- Consider spot instances for testing
- Use smaller EBS volumes
- Implement auto-shutdown for non-working hours

### **Resource Monitoring**
- Monitor CPU and memory usage
- Track EBS volume usage
- Set up CloudWatch alarms for costs
- Use AWS Cost Explorer for analysis

## Migration Path

### **To Multi-Node Cluster**
When ready to scale up:
1. Use the `ha/` example for high availability
2. Use the `prod/` example for enterprise features
3. Use the `splitrole/` example for advanced configurations

### **Data Migration**
- Backup etcd data before migration
- Export application manifests
- Plan for minimal downtime
- Test migration process thoroughly

## Best Practices

### **Development Workflow**
- Use this for rapid iteration
- Keep configurations in version control
- Document custom configurations
- Regular cleanup to avoid costs

### **Security**
- Use strong SSH keys
- Implement proper IAM roles
- Regular security updates
- Monitor access logs

### **Backup Strategy**
- Regular etcd backups
- Export important manifests
- Document configurations
- Test recovery procedures

## Additional Resources

- [RKE2 Documentation](https://docs.rke2.io/)
- [Kubernetes Single Node Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [RKE2 Troubleshooting](https://docs.rke2.io/troubleshooting/)

## Contributing

This example is used as a test fixture, so please:
- Test changes thoroughly
- Maintain backward compatibility
- Update documentation
- Follow existing patterns
