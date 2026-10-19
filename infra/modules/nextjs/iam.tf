resource "aws_iam_role" "function" {
  for_each = local.functions

  name = "${var.name}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

locals {
  table_statement = {
    Effect   = "Allow"
    Action   = ["dynamodb:BatchGetItem", "dynamodb:BatchWriteItem", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query"]
    Resource = [aws_dynamodb_table.cache.arn, "${aws_dynamodb_table.cache.arn}/index/*"]
  }
  function_statements = {
    server = [
      local.table_statement,
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.app.arn}/_cache/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.revalidation.arn]
      }
    ]
    image = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["${aws_s3_bucket.app.arn}/_assets/*"]
    }]
    revalidation = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = [aws_sqs_queue.revalidation.arn]
    }]
    initializer = [{
      Effect   = "Allow"
      Action   = ["dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:DescribeTable"]
      Resource = [aws_dynamodb_table.cache.arn]
    }]
  }
}

resource "aws_iam_role_policy" "function" {
  for_each = local.functions

  name = "${var.name}-${each.key}"
  role = aws_iam_role.function[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${aws_cloudwatch_log_group.function[each.key].arn}:*"]
      }
    ], local.function_statements[each.key])
  })
}