# ECS Configuration

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

# ECS Task Definition from file
locals {
  task_definition = templatefile("${path.module}/task-definition.json", {
    execution_role_arn = aws_iam_role.ecs_task_execution.arn
    ecr_repository_url = aws_ecr_repository.app.repository_url
  })
}

# ECS Service with Blue/Green Deployment
resource "aws_ecs_service" "app" {
  name                       = var.service_name
  cluster                    = aws_ecs_cluster.main.id
  task_definition            = local.task_definition
  desired_count              = 1
  deployment_maximum_percent = 200
  launch_type                = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = 5

    lifecycle_hook {
      hook_target_arn  = aws_lambda_function.health_check_test.arn
      role_arn         = aws_iam_role.ecs_blue_green.arn
      lifecycle_stages = ["POST_TEST_TRAFFIC_SHIFT"]
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.service_name
    container_port   = 8080

    advanced_configuration {
      alternate_target_group_arn = aws_lb_target_group.green.arn
      production_listener_rule   = aws_lb_listener_rule.production.arn
      test_listener_rule         = aws_lb_listener_rule.test.arn
      role_arn                   = aws_iam_role.ecs_blue_green.arn
    }
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  depends_on = [aws_lb_listener.production, aws_lb_listener.test]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs" {
  name        = "${var.service_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.service_name}-ecs-sg"
  }
}

# ECS Security Group Rules
resource "aws_security_group_rule" "ecs_ingress_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
  description              = "Allow traffic from ALB"
}

resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
  description       = "Allow all outbound traffic"
}