# Terraform Configuration
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Project     = "ecs-blue-green-demo"
      Environment = "demo"
      ManagedBy   = "terraform"
      Service     = var.service_name
    }
  }
}