# Terraform AWS RKE2 Examples

This directory contains comprehensive examples for deploying RKE2 (Rancher Kubernetes Engine 2) clusters on AWS using Terraform. Each example demonstrates different deployment patterns, complexity levels, and use cases.

## 📋 Example Overview

| Example | Complexity | Use Case | Description |
|---------|------------|----------|-------------|
| [`one/`](./one/) | ⭐ | Development/Testing | Single node cluster for development and testing |
| [`ha/`](./ha/) | ⭐⭐⭐ | Production/Staging | High availability cluster with multiple control plane nodes |
| [`prod/`](./prod/) | ⭐⭐⭐⭐⭐ | Enterprise Production | Enterprise-grade cluster with enhanced security and compliance |
| [`splitrole/`](./splitrole/) | ⭐⭐⭐⭐ | Advanced Production | Separate control plane and worker node management |

## 🎯 Choosing the Right Example

### **For Development & Testing**
**Use: [`one/`](./one/)**
- Single node deployment with combined control plane + worker
- Quick setup and teardown for rapid iteration
- Minimal AWS resources and costs
- Perfect for learning, testing, and proof-of-concept
- Complete RKE2 functionality in a single node

### **For Production/Staging**
**Use: [`ha/`](./ha/)**
- Multi-AZ high availability
- Load balancer for control plane
- Auto scaling groups
- Suitable for most production workloads

### **For Enterprise Production**
**Use: [`prod/`](./prod/)**
- Enhanced security and compliance
- Comprehensive monitoring
- Backup and disaster recovery
- Enterprise-grade features

### **For Advanced Use Cases**
**Use: [`splitrole/`](./splitrole/)**
- Independent control plane and worker scaling
- Different instance types per role
- Multi-tenant environments
- GPU workloads and specialized requirements

## ⚠️ Important Note: All Examples Are HA (Except `one/`)

**`ha/`, `prod/`, and `splitrole` all provide high availability** with:
- Multiple control plane nodes across 3 availability zones
- Load balancers for control plane access
- Auto scaling groups for both control plane and worker nodes
- Multi-AZ deployment for fault tolerance

### **What Actually Differentiates Them:**

| Example | Focus | Key Differentiator |
|---------|-------|-------------------|
| `ha/` | **Standard HA** | Basic high availability with standard security and monitoring |
| `prod/` | **Enterprise HA** | Enhanced security, compliance, monitoring, and operational features |
| `splitrole/` | **Flexible HA** | Independent control plane/worker management with role-specific configurations |

**Think of it as:**
- `ha/` = "Standard HA" (good for most production)
- `prod/` = "Enterprise HA" (enhanced features for enterprise)
- `splitrole/` = "Flexible HA" (operational flexibility with same HA architecture)

## 🚀 Quick Start

### Prerequisites
- Terraform (v1.5.7+)
- AWS CLI configured with appropriate permissions
- SSH key pair for node access
- Understanding of RKE2 architecture

### Basic Deployment Steps
1. **Choose an example** based on your requirements
2. **Navigate to the example directory**:
   ```bash
   cd examples/[example-name]
   ```
3. **Configure variables**:
   ```bash
   cp variables.tf variables.tfvars
   # Edit variables.tfvars with your values
   ```
4. **Initialize Terraform**:
   ```bash
   terraform init
   ```
5. **Plan the deployment**:
   ```bash
   terraform plan
   ```
6. **Apply the configuration**:
   ```bash
   terraform apply
   ```

## 📊 Resource Comparison

| Resource | one | ha | prod | splitrole |
|----------|-----|----|------|-----------|
| Control Plane Nodes | 1 (combined) | 3+ | 3+ | 3+ |
| Worker Nodes | 0 (same node) | 3+ | 3+ | 3+ |
| Load Balancer | ❌ | ✅ | ✅ | ✅ |
| Auto Scaling | ❌ | ✅ | ✅ | ✅ |
| Multi-AZ | ❌ | ✅ | ✅ | ✅ |
| High Availability | ❌ | ✅ | ✅ | ✅ |
| Enhanced Security | ❌ | ❌ | ✅ | ✅ |
| Monitoring | Basic | Basic | Advanced | Advanced |
| Backup/DR | ❌ | ❌ | ✅ | ✅ |
| Compliance | ❌ | ❌ | ✅ | ✅ |
| Development Ready | ✅ | ❌ | ❌ | ❌ |

## 🔧 Common Customizations

### Instance Types
All examples allow customization of instance types:
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}
```

### Node Count
Adjust the number of nodes per role:
```hcl
variable "control_plane_count" {
  description = "Number of control plane nodes"
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  default     = 3
}
```

### Networking
Customize VPC and subnet configurations:
```hcl
variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}
```

## 🔒 Security Considerations

### Network Security
- All examples use private subnets for worker nodes
- Security groups restrict access appropriately
- NAT gateways provide internet access for private subnets

### IAM Security
- Least privilege access policies
- Role-based access control
- Instance profiles for node permissions

### Encryption
- EBS volumes encrypted at rest
- TLS encryption in transit
- Secrets management integration

## 💰 Cost Optimization

### Development/Testing
- Use `one/` example for minimal costs (single node)
- Consider spot instances for worker nodes
- Use smaller instance types (t3.small/medium)
- Implement auto-shutdown for non-working hours
- Regular cleanup to avoid costs

### Production
- Use reserved instances for predictable workloads
- Implement auto scaling for cost efficiency
- Monitor and right-size resources

### Enterprise
- Implement comprehensive cost monitoring
- Use appropriate storage classes
- Optimize network traffic

## 🛠️ Troubleshooting

### Common Issues

**Node Join Failures**
- Check security group rules
- Verify SSH key configuration
- Ensure proper IAM permissions
- Review RKE2 logs: `journalctl -u rke2-server`

**Load Balancer Issues**
- Verify target group health checks
- Check security group configurations
- Ensure proper subnet routing

**Scaling Problems**
- Review auto scaling group configurations
- Check CloudWatch alarms
- Verify instance type availability

**Single Node Issues (one/ example)**
- Check instance health and SSH access
- Verify CNI installation (Calico/Cilium)
- Review node resources and capacity
- Ensure proper VPC and subnet configuration

### Getting Help
- Check the [main module documentation](../README.md)
- Review [RKE2 documentation](https://docs.rke2.io/)
- Open an issue in the repository

## 📚 Additional Resources

- [RKE2 Documentation](https://docs.rke2.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.amazon.com/eks/resources/best-practices/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

## 🤝 Contributing

We welcome contributions! Please:
1. Test your changes thoroughly
2. Update documentation as needed
3. Follow the existing code style
4. Add appropriate tests

## 📄 License

This project is licensed under the same terms as the main module. See the [LICENSE](../LICENSE) file for details. 