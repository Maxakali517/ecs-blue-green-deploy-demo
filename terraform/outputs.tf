# Output values for the ECS Blue/Green deployment

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.app.zone_id
}

output "production_url" {
  description = "Production URL (port 80)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "test_url" {
  description = "Test URL (port 8080)"
  value       = "http://${aws_lb.app.dns_name}:8080"
}

output "blue_target_group_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the green target group"
  value       = aws_lb_target_group.green.arn
}

output "production_listener_arn" {
  description = "ARN of the production listener"
  value       = aws_lb_listener.production.arn
}

output "test_listener_arn" {
  description = "ARN of the test listener"
  value       = aws_lb_listener.test.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "task_definition_content" {
  description = "Task definition content from file"
  value       = local.task_definition
}

# Health Check Lambda outputs
output "health_check_lambda_arn" {
  description = "ARN of the health check Lambda function"
  value       = aws_lambda_function.health_check_test.arn
}

