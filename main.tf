terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "hardware_logs" {
  name           = "AHLMS-Hardware-Logs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "SerialNumber"

  attribute {
    name = "SerialNumber"
    type = "S"
  }
}

# 1. Package the Python code into a Zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "scan_processor.zip"
}

# 2. Create a security role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "ahlms_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 3. Build the actual Lambda function in AWS
resource "aws_lambda_function" "scan_processor" {
  filename         = "scan_processor.zip"
  function_name    = "AHLMS-Scan-Processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scan_processor.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 4. Give Lambda permission to write to DynamoDB
resource "aws_iam_policy" "dynamodb_access" {
  name        = "LambdaDynamoDBAccess"
  description = "Allows Lambda to write to the AHLMS hardware logs"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [{
    Action = [
         "dynamodb:PutItem",
         "dynamodb:Scan",
         "dynamodb:GetItem",
         "rekognition:DetectText"
       ]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.hardware_logs.arn
    }]
  })
}

# 5. Attach the policy to our Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}


# 6. Create the API Gateway
resource "aws_apigatewayv2_api" "ahlms_api" {
  name          = "AHLMS-API"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}
# 7. Connect the API Gateway to our Lambda Function
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.ahlms_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.scan_processor.invoke_arn
}

# 8. Create a Route for the API (POST request)
resource "aws_apigatewayv2_route" "post_scan" {
  api_id    = aws_apigatewayv2_api.ahlms_api.id
  route_key = "POST /scan"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 9. Deploy the API
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.ahlms_api.id
  name        = "$default"
  auto_deploy = true
}

# 10. Give API Gateway permission to trigger the Lambda
resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scan_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ahlms_api.execution_arn}/*/*"
}

# 11. Print out the final URL so we can use it!
output "api_endpoint" {
  value = "${aws_apigatewayv2_api.ahlms_api.api_endpoint}/scan"
}