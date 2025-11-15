# EC2 Infrastructure

This directory contains Terraform configuration for provisioning VPC, networking, and a jumphost EC2 instance for managing the EKS cluster.

## Prerequisites

Before deploying the EC2 infrastructure, you **must** create the S3 bucket and DynamoDB table for Terraform state management.

### 1. Create S3 Bucket for Terraform State

```bash
aws s3api create-bucket \
  --bucket aws-eks-terraform-github-action-tf-state \
  --region us-east-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket aws-eks-terraform-github-action-tf-state \
  --versioning-configuration Status=Enabled
```

Enable encryption:

```bash
aws s3api put-bucket-encryption \
  --bucket aws-eks-terraform-github-action-tf-state \
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
  --table-name Lock-Files \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Verify Resources

Verify S3 bucket:
```bash
aws s3 ls | grep aws-eks-terraform-github-action-tf-state
```

Verify DynamoDB table:
```bash
aws dynamodb describe-table --table-name Lock-Files --region us-east-1
```

## What Gets Created

This Terraform configuration creates:

### VPC and Networking
- **VPC**: `microservices-ecommerce-eks-vpc` (10.0.0.0/16)
- **Internet Gateway**: For public internet access
- **Public Subnets**:
  - `Public-Subnet-1` (10.0.1.0/24) in us-east-1a
  - `Public-subnet2` (10.0.0.0/24) in us-east-1b
- **Private Subnets**:
  - `Private-subnet1` (10.0.2.0/24) in us-east-1a
  - `Private-subnet2` (10.0.3.0/24) in us-east-1b
- **Route Tables**: Public and private route tables with associations
- **Security Group**: `microservices-ecommerce-eks-sg` with ports 22, 80, 443, 3306, 8080, 9000, 9090

### EC2 Instance (Jumphost)
- **Instance Name**: Jumphost-server
- **Instance Type**: t2.large
- **Root Volume**: 30 GB
- **AMI**: Amazon Linux 2023 (us-east-1)
- **Access Method**: AWS Systems Manager Session Manager (no SSH keys required)

### IAM Resources
- **IAM Role**: `Jumphost-iam-role1` with comprehensive permissions
- **IAM Instance Profile**: For EC2 instance
- **IAM Policies Attached**:
  - AdministratorAccess (for testing - use least privilege in production)
  - AmazonEC2FullAccess
  - AmazonEKSClusterPolicy
  - AmazonEKSWorkerNodePolicy
  - AWSCloudFormationFullAccess
  - IAMFullAccess
  - AmazonSSMManagedInstanceCore (for Session Manager)
  - Custom EKS policy

## Important Notes

⚠️ **This infrastructure must be deployed before the EKS cluster** as it creates:
- The VPC that EKS will use
- The subnets where EKS nodes will run
- The security group for EKS cluster

The resources are tagged with specific names that the EKS infrastructure expects to find.

## Deployment via GitHub Actions

1. Navigate to **Actions** → **Step 2 - Deploy EC2 Infrastructure**
2. Click **Run workflow**
3. Select action:
   - `plan` - Preview changes
   - `apply` - Create resources
   - `destroy` - Delete resources
4. Click **Run workflow**

## Local Deployment

### Initialize Terraform
```bash
cd infra/ec2
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

## Accessing the Jumphost

The jumphost server is accessible via **AWS Systems Manager Session Manager** (no SSH keys required).

### Via AWS CLI
```bash
# Get the instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Jumphost-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

# Start a session
aws ssm start-session --target $INSTANCE_ID
```

### Via AWS Console
1. Navigate to **Systems Manager** → **Session Manager**
2. Click **Start session**
3. Select the **Jumphost-server** instance
4. Click **Start session**

## Pre-installed Tools

The jumphost comes with the following tools pre-installed (via `install-tools.sh`):
- AWS CLI
- kubectl
- eksctl
- Terraform
- Docker
- Git
- And other common utilities

## Network Architecture

```
VPC (10.0.0.0/16)
├── Internet Gateway
├── Public Subnets (with Internet access)
│   ├── Public-Subnet-1 (10.0.1.0/24) - AZ: us-east-1a
│   │   └── Jumphost EC2 Instance
│   └── Public-subnet2 (10.0.0.0/24) - AZ: us-east-1b
│       └── (EKS Load Balancers)
└── Private Subnets (no direct Internet access)
    ├── Private-subnet1 (10.0.2.0/24) - AZ: us-east-1a
    └── Private-subnet2 (10.0.3.0/24) - AZ: us-east-1b
```

## EKS Integration

The VPC and subnets are tagged for EKS integration:
- `kubernetes.io/role/elb = 1` - Allows EKS to create load balancers
- `kubernetes.io/cluster/microservices-ecommerce-eks-cluster = shared` - Shared with EKS cluster

## Security Considerations

⚠️ **Important Security Notes**:
1. The jumphost has **AdministratorAccess** for testing purposes
2. **In production**, replace with least privilege IAM policies
3. The security group allows traffic from `0.0.0.0/0` on several ports
4. **In production**, restrict to specific IP ranges or VPN

## Troubleshooting

### Error: Error acquiring the state lock
**Solution**: Ensure the DynamoDB table `Lock-Files` exists (see prerequisites above).

### Error: Unsupported Terraform Core version
**Solution**: The workflow uses Terraform 1.8.4. Ensure your local version matches if running locally.

### Cannot connect to Session Manager
**Solution**: 
- Ensure the instance is running
- Verify IAM role has `AmazonSSMManagedInstanceCore` policy
- Check SSM agent is running on the instance

## Clean Up

To destroy the EC2 infrastructure:

1. **First destroy EKS cluster** (if deployed)
2. Via GitHub Actions: Select `destroy` action in the workflow
3. Via Local: Run `terraform destroy` in this directory

**Note**: You cannot destroy the VPC while EKS resources are still using it.

## Configuration Variables

You can customize the deployment by modifying `variables.tf`:

- `region` - AWS region (default: us-east-1)
- `vpc-name` - VPC name tag
- `instance_type` - EC2 instance type (default: t2.large)
- `ami_id` - AMI ID for the jumphost
- Subnet names and other resource names

## Next Steps

After deploying this infrastructure:
1. Verify the VPC and subnets are created
2. Access the jumphost via Session Manager
3. Deploy the EKS cluster using the `infra/eks` configuration
