locals {
  lambda_name = "${var.project}_apigw_contact_handler"
}

# Create the resource & endpoint
resource "aws_api_gateway_resource" "contact" {
  parent_id   = var.parent_resource_id != "" ? var.parent_resource_id : var.api.root_resource_id
  path_part   = var.path
  rest_api_id = var.api.id
}
resource "aws_api_gateway_method" "contact" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.contact.id
  rest_api_id   = var.api.id
}

# Create cloudwatch log bucket for the lambda
# The name is important! Lambda will automatically write to specified group (if its created
# and we assign it the required permissions)
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 180
}


# Create the iam role for the lambda to send emails via SES and write logs to cloudwatch
resource "aws_iam_role" "lambda" {
  name               = "${var.project}_contact_form_ses_sender"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Effect": "Allow",
      "Sid": "AllowLambda"
    }
  ]
}
EOF

  # Grant the lambda various permissions...
  # Note that for SES we grant access to multiple identies (not all of which may exist...)
  # One of the email SENDER or the full DOMAIN need to be verified to be used as a from address
  # If SES is running in sandbox mode we can also only send emails to addresses we prove
  # we own, and as such the RECEIVER must also be granted just in case
  inline_policy {
    name   = "${var.project}_ses_sender"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Sid": "AllowSes",
        "Effect": "Allow",
        "Action": [ "ses:SendEmail", "ses:SendRawEmail" ],
        "Resource": [
            "arn:aws:ses:*:*:identity/${var.env.RECEIVER}",
            "arn:aws:ses:*:*:identity/${var.env.SENDER}",
            "arn:aws:ses:*:*:identity/${var.env.DOMAIN}"
        ]
    }, {
       "Sid": "AllowCloudwatchCreateStream",
        "Effect": "Allow",
        "Action": [ "logs:CreateLogStream" ],
        "Resource": "${aws_cloudwatch_log_group.lambda.arn}:*"
    }, {
       "Sid": "AllowCloudwatchPutEvent",
        "Effect": "Allow",
        "Action": [ "logs:PutLogEvents" ],
        "Resource": "${aws_cloudwatch_log_group.lambda.arn}:*:*"
    }]
}
EOF
  }
}

# Create the lambda to handle requests
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/code"
  output_path = "${path.module}/code.zip"
}
resource "aws_lambda_function" "lambda" {
  function_name    = local.lambda_name
  runtime          = "nodejs14.x"
  role             = aws_iam_role.lambda.arn
  description      = "Handles web contact forms for ${var.project}"
  handler          = "lambda.handler"
  filename         = "${path.module}/code.zip"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  publish          = false # don't bother with versioned deployments, just always use the latest code
  timeout          = 10    # network request to google recaptcha and aws-ses is required
  environment {
    variables = var.env
  }
}

# Wire up API gateway to call the lambda
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_api_gateway_integration" "contact" {
  rest_api_id             = var.api.id
  resource_id             = aws_api_gateway_resource.contact.id
  http_method             = aws_api_gateway_method.contact.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.api.id}/*/${aws_api_gateway_method.contact.http_method}${aws_api_gateway_resource.contact.path}"
}
