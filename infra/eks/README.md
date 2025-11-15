# EKS Infrastructure

This directory contains Terraform configuration for provisioning an Amazon EKS cluster with managed node groups.

## Prerequisites

Before deploying the EKS infrastructure, you **must** create the S3 bucket and DynamoDB table for Terraform state management.

### 1. Create S3 Bucket for EKS Terraform State

```bash
aws s3api create-bucket \
  --bucket microservices-ecommerce-eks-cluster-terraform-state \
  --region us-east-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket microservices-ecommerce-eks-cluster-terraform-state \
  --versioning-configuration Status=Enabled
```

Enable encryption:

```bash
aws s3api put-bucket-encryption \
  --bucket microservices-ecommerce-eks-cluster-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Verify Resources

Verify S3 bucket:
```bash
aws s3 ls | grep microservices-ecommerce-eks-cluster-terraform-state
```

Verify DynamoDB table:
```bash
aws dynamodb describe-table --table-name terraform-state-locks --region us-east-1
```

## Important Notes

⚠️ **The EC2 infrastructure must be deployed first** as the EKS cluster requires:
- VPC with tag: `Name = "microservices-ecommerce-eks-vpc"`
- Public subnets with tags: `Name = "Public-Subnet-1"` and `Name = "Public-subnet2"`
- Security group with tag: `Name = "microservices-ecommerce-eks-sg"`

## What Gets Created

This Terraform configuration creates:

- **EKS Cluster**: `microservices-ecommerce-eks-cluster`
- **IAM Role for EKS Master**: `microservices-ecommerce-eks-master1`
- **IAM Role for Worker Nodes**: `microservices-ecommerce-eks-worker1`
- **EKS Node Group**: Managed node group with auto-scaling
- **OIDC Provider**: For Kubernetes service account IAM roles
- **IAM Policies**: Various policies for cluster and worker node permissions

## Deployment via GitHub Actions

1. Navigate to **Actions** → **EKS Infrastructure**
2. Click **Run workflow**
3. Select action:
   - `plan` - Preview changes
   - `apply` - Create resources
   - `destroy` - Delete resources
4. Click **Run workflow**

## Local Deployment

### Initialize Terraform
```bash
cd infra/eks
terraform init
```

### Plan Changes
```bash
terraform plan
```

### Apply Configuration
```bash
terraform apply
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Accessing the EKS Cluster

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name microservices-ecommerce-eks-cluster
```

Verify access:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Configuration Details

### Node Group Settings
- **Instance Type**: t2.large
- **Disk Size**: 20 GB
- **Capacity Type**: ON_DEMAND
- **Min Nodes**: 2
- **Max Nodes**: 10
- **Desired Nodes**: 3

### IAM Policies Attached
- AmazonEKSClusterPolicy
- AmazonEKSServicePolicy
- AmazonEKSVPCResourceController
- AmazonEKSWorkerNodePolicy
- AmazonEKS_CNI_Policy
- AmazonSSMManagedInstanceCore
- AmazonEC2ContainerRegistryReadOnly
- AmazonS3ReadOnlyAccess
- Custom autoscaler policy

## Troubleshooting

### Error: no matching EC2 VPC found
**Solution**: Deploy the EC2 infrastructure first to create the required VPC.

### Error: Error acquiring the state lock
**Solution**: Ensure the DynamoDB table `terraform-state-locks` exists (see prerequisites above).

### Error: Unsupported Terraform Core version
**Solution**: The workflow uses Terraform 1.8.4. Ensure your local version matches if running locally.

## Clean Up

To destroy the EKS cluster:

1. Via GitHub Actions: Select `destroy` action in the workflow
2. Via Local: Run `terraform destroy` in this directory

**Note**: Destroy EKS before destroying EC2 infrastructure to avoid dependency issues.
