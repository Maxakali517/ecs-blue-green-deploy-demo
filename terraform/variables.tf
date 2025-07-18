# Variables for ECS Blue/Green deployment

variable "cluster_name" {
  description = "ECS Cluster name"
  type        = string
  default     = "blue-green-demo"
}

variable "service_name" {
  description = "ECS Service name"
  type        = string
  default     = "blue-green-demo"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}