terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

# IAM Role Creation

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM Policy Creation: Allow Cloudwatch Logging

resource "aws_iam_policy" "allow_logging" {
  name        = "allow_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# IAM Policy Creation: Allow Kinesis Processing

resource "aws_iam_policy" "allow_kinesis_processing" {
  name        = "allow_kinesis_processing"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "kinesis:ListShards",
        "kinesis:ListStreams",
        "kinesis:*"
      ],
      "Resource": "arn:aws:kinesis:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "stream:GetRecord",
        "stream:GetShardIterator",
        "stream:DescribeStream",
        "stream:*"
      ],
      "Resource": "arn:aws:stream:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Attach IAM Policies to Roles

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.allow_logging.arn
}

resource "aws_iam_role_policy_attachment" "kinesis_processing" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.allow_kinesis_processing.arn
}

# Create Kinesis Data Stream

resource "aws_kinesis_stream" "kinesis_stream" {
  name             = "terraform-kinesis-stream"
  shard_count      = 2
  retention_period = 48

  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
  ]

  tags = {
    CreatedBy = "terraform-kinesis-lambda"
  }
}

# Build Lambda Zip

resource "null_resource" "build_zip" {
  provisioner "local-exec" {
    command = "zip lambda_function.zip lambda_function.py"
  }
}

# Create AWS Lambda

resource "aws_lambda_function" "test_lambda" {
  filename      = "lambda_function.zip"
  function_name = "terraform-kinesis-lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("lambda_function.zip")

  runtime = "python3.8"

  environment {
    variables = {
      DATA_STREAM_NAME = "someKinesis"
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "example" {
  function_name                = aws_lambda_function.test_lambda.function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}

# Create Lambda Event Source Mapping

resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn  = aws_kinesis_stream.kinesis_stream.arn
  function_name     = aws_lambda_function.test_lambda.arn
  starting_position = "LATEST"

  depends_on = [
    aws_iam_role_policy_attachment.kinesis_processing
  ]
}
