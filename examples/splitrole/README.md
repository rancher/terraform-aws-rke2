# Example Split Role Cluster

This example demonstrates how to deploy an RKE2 cluster with separate control plane and worker node configurations, allowing for different instance types, scaling policies, and operational requirements for each role.

## Overview

The split role configuration separates control plane and worker node management, providing:
- **Independent Scaling**: Control plane and worker nodes can scale independently
- **Different Instance Types**: Optimize resources for specific roles
- **Separate Security Groups**: Different network policies for each role
- **Role-Specific Configurations**: Custom settings for control plane vs worker nodes
- **Flexible Deployment**: Deploy control plane and workers in different patterns

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Split Role Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Control Plane Layer                    │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Control     │  │ Control     │  │ Control     │  │   │
│  │  │ Plane       │  │ Plane       │  │ Plane       │  │   │
│  │  │ (Dedicated) │  │ (Dedicated) │  │ (Dedicated) │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Worker Node Layer                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Worker      │  │ Worker      │  │ Worker      │  │   │
│  │  │ (General)   │  │ (General)   │  │ (General)   │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  │                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ Worker      │  │ Worker      │  │ Worker      │  │   │
│  │  │ (GPU)       │  │ (GPU)       │  │ (GPU)       │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Load Balancer Layer                    │   │
│  │  ┌─────────────────┐  ┌─────────────────────────┐  │   │
│  │  │ Control Plane   │  │ Worker Node             │  │   │
│  │  │ Load Balancer   │  │ Load Balancer           │  │   │
│  │  └─────────────────┘  └─────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Key Benefits

### Independent Management
- **Separate Auto Scaling Groups**: Control plane and worker nodes scale independently
- **Different Update Strategies**: Rolling updates can be applied separately
- **Role-Specific Monitoring**: Different metrics and alerts for each role
- **Custom Configurations**: Instance types, storage, and networking optimized per role

### Resource Optimization
- **Control Plane**: Dedicated instances for consistent performance
- **Worker Nodes**: General purpose or specialized instances based on workloads
- **Storage Optimization**: Different EBS configurations per role
- **Network Optimization**: Role-specific security groups and routing

### Operational Flexibility
- **Blue-Green Deployments**: Update worker nodes without affecting control plane
- **Canary Deployments**: Test new configurations on subset of workers
- **Maintenance Windows**: Schedule maintenance per role
- **Disaster Recovery**: Different recovery strategies for each role

## Use Cases

### Development/Testing
- Small control plane with multiple worker node types
- GPU workers for ML workloads
- Spot instances for cost optimization

### Production Workloads
- Dedicated control plane with high availability
- Multiple worker node pools for different workload types
- Separate scaling policies based on demand

### Multi-Tenant Environments
- Isolated worker node pools per tenant
- Shared control plane with tenant-specific configurations
- Resource quotas and limits per worker pool

## Configuration Files

- **`main.tf`**: Main Terraform configuration
- **`cp_main.tf.tftpl`**: Control plane node template
- **`agent_main.tf.tftpl`**: Worker node template
- **`variables.tf`**: Configuration variables
- **`outputs.tf`**: Output values

## Requirements

- Terraform (v1.5.7+)
- AWS CLI with appropriate permissions
- Understanding of RKE2 architecture and roles
- Network planning for role separation

## Usage

1. **Plan Architecture**: Determine control plane and worker node requirements
2. **Configure Variables**: Set role-specific configurations
3. **Deploy Control Plane**: Deploy control plane nodes first
4. **Deploy Worker Nodes**: Add worker nodes to the cluster
5. **Validate**: Ensure all nodes join the cluster correctly

## Important Considerations

### Control Plane
- Minimum 3 nodes for high availability
- Use dedicated instances for consistent performance
- Implement proper backup and recovery procedures
- Monitor control plane health and performance

### Worker Nodes
- Scale based on workload requirements
- Use appropriate instance types for workloads
- Implement node labeling and taints for workload placement
- Monitor resource utilization and performance

### Networking
- Ensure proper network connectivity between roles
- Configure security groups appropriately
- Plan for cross-AZ communication
- Consider VPC endpoints for AWS service access

## Monitoring & Maintenance

### Control Plane Monitoring
- API server health and performance
- etcd cluster health
- Control plane node resource utilization
- Backup and recovery status

### Worker Node Monitoring
- Node health and readiness
- Resource utilization (CPU, memory, storage)
- Application performance metrics
- Scaling metrics and trends

## Cost Optimization

- **Control Plane**: Use reserved instances for predictable costs
- **Worker Nodes**: Mix of on-demand, reserved, and spot instances
- **Storage**: Use appropriate EBS volume types per role
- **Networking**: Optimize for minimal cross-AZ traffic

## Security Considerations

- **IAM Roles**: Different roles for control plane and worker nodes
- **Security Groups**: Role-specific network policies
- **Encryption**: Ensure encryption at rest and in transit
- **Access Control**: Implement proper RBAC and network policies 