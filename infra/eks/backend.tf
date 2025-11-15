terraform {
  required_version = ">= 1.8.4" # Allow Terraform 1.8.4 and newer versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49.0"
    }
  }
  backend "s3" {
    bucket         = "microservices-ecommerce-eks-cluster-terraform-state"
    region         = "us-east-1"
    key            = "eks/terraform.tfstate"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}