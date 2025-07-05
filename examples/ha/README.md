# Example High Availability (HA) Cluster

This example demonstrates how to deploy a highly available RKE2 cluster with multiple control plane nodes and worker nodes across multiple availability zones.

## Overview

This configuration creates a production-ready RKE2 cluster with:
- **Multiple Control Plane Nodes**: Distributed across availability zones for high availability
- **Worker Nodes**: Scalable worker nodes for running workloads
- **Load Balancer**: Application Load Balancer for distributing traffic to control plane nodes
- **Auto Scaling Groups**: For both control plane and worker nodes
- **Multi-AZ Deployment**: Resources distributed across availability zones for fault tolerance

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AZ-1          │    │   AZ-2          │    │   AZ-3          │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Control     │ │    │ │ Control     │ │    │ │ Control     │ │
│ │ Plane Node  │ │    │ │ Plane Node  │ │    │ │ Plane Node  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Worker      │ │    │ │ Worker      │ │    │ │ Worker      │ │
│ │ Node        │ │    │ │ Node        │ │    │ │ Node        │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Application     │
                    │ Load Balancer   │
                    └─────────────────┘
```

## Key Features

- **High Availability**: Control plane nodes distributed across multiple AZs
- **Auto Scaling**: Both control plane and worker nodes can scale automatically
- **Load Balancing**: ALB distributes traffic to healthy control plane nodes
- **Security**: VPC with private subnets, security groups, and IAM roles
- **Monitoring**: CloudWatch integration for monitoring and logging
- **Backup**: EBS snapshots and automated backup strategies

## Requirements

- Terraform (v1.5.7+)
- AWS CLI configured with appropriate permissions
- SSH key pair for node access
- Sufficient AWS quotas for the resources being created

## Usage

1. **Configure Variables**: Update `variables.tf` or create a `terraform.tfvars` file
2. **Initialize**: `terraform init`
3. **Plan**: `terraform plan`
4. **Apply**: `terraform apply`

## Important Notes

- This example creates a substantial amount of AWS resources
- Ensure you have sufficient AWS service quotas for the region
- The cluster will take several minutes to fully initialize
- Control plane nodes use dedicated instances for better performance
- Worker nodes can be scaled independently based on workload requirements

## Post-Deployment

After deployment, you'll need to:
1. Configure kubectl to connect to the cluster
2. Install CNI (Calico or Cilium configuration files provided)
3. Configure monitoring and logging
4. Set up backup and disaster recovery procedures

## Cost Considerations

This HA setup includes:
- Multiple EC2 instances across AZs
- Application Load Balancer
- EBS volumes for persistent storage
- NAT Gateways for private subnet internet access
- CloudWatch monitoring

Consider the costs associated with running multiple instances and cross-AZ traffic. 