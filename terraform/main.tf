# ECS Blue/Green Deployment Configuration
# Based on the latest AWS Terraform Registry and best practices

# This file serves as the main entry point for the Terraform configuration
# All resources have been organized into separate files for better maintainability:
# - vpc.tf: VPC and networking resources
# - security_groups.tf: Security groups and rules
# - ecs.tf: ECS cluster, task definition, and service
# - alb.tf: Application Load Balancer and target groups
# - iam.tf: IAM roles and policies
# - ecr.tf: ECR repository and policies
# - cloudwatch.tf: CloudWatch log groups
# - variables.tf: Input variables
# - outputs.tf: Output values