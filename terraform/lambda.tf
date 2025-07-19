# Lambda functions for ECS Blue/Green deployment automation

# Health Check Test Lambda function
resource "aws_lambda_function" "health_check_test" {
  filename      = data.archive_file.health_check_test_lambda.output_path
  function_name = "${var.service_name}-health-check-test"
  role          = aws_iam_role.lambda_health_check.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300 # 5 minutes

  source_code_hash = data.archive_file.health_check_test_lambda.output_base64sha256

  environment {
    variables = {
      TEST_ENDPOINT_URL = "http://${aws_lb.app.dns_name}:8080"
    }
  }

  tags = {
    Project   = "ecs-blue-green-demo"
    Service   = var.service_name
    ManagedBy = "terraform"
  }
}

data "archive_file" "health_check_test_lambda" {
  type        = "zip"
  output_path = "${path.module}/health_check_test_lambda.zip"
  source {
    content  = file("${path.module}/lambda_functions/health_check_test.py")
    filename = "lambda_function.py"
  }
}


# Lambda permission for ECS to invoke health check function
resource "aws_lambda_permission" "ecs_health_check" {
  statement_id  = "AllowExecutionFromECS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_check_test.function_name
  principal     = "ecs.amazonaws.com"
}