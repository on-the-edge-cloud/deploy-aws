data "archive_file" "function" {
  for_each = var.deploy_artifacts ? local.functions : {}

  type        = "zip"
  source_dir  = "${var.build_path}/${each.value}"
  output_path = "${var.build_path}/.build/${each.key}.zip"
}

resource "aws_s3_object" "function" {
  for_each = var.deploy_artifacts ? local.functions : {}

  bucket      = aws_s3_bucket.app.id
  key         = "_functions/${each.key}.zip"
  source      = data.archive_file.function[each.key].output_path
  source_hash = data.archive_file.function[each.key].output_base64sha256

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.app]
}

resource "aws_cloudwatch_log_group" "function" {
  for_each = local.functions

  name              = "/aws/lambda/${var.name}-${each.key}"
  retention_in_days = 7
}

resource "aws_lambda_function" "app" {
  for_each = local.functions

  function_name    = "${var.name}-${each.key}"
  role             = aws_iam_role.function[each.key].arn
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  handler          = "index.handler"
  s3_bucket        = aws_s3_bucket.app.id
  s3_key           = "_functions/${each.key}.zip"
  source_code_hash = var.deploy_artifacts ? data.archive_file.function[each.key].output_base64sha256 : null
  memory_size      = each.key == "server" || each.key == "image" ? 1024 : 256
  timeout          = each.key == "initializer" ? 120 : 30

  environment {
    variables = each.key == "image" ? {
      BUCKET_NAME       = aws_s3_bucket.app.bucket
      BUCKET_KEY_PREFIX = "_assets"
    } : local.cache_environment
  }

  depends_on = [aws_s3_object.function, aws_iam_role_policy.function, aws_cloudwatch_log_group.function]
}

resource "aws_lambda_function_url" "app" {
  for_each = toset(["server", "image"])

  function_name      = aws_lambda_function.app[each.key].function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "url" {
  for_each = aws_lambda_function_url.app

  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app[each.key].function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "invoke" {
  for_each = aws_lambda_function_url.app

  statement_id             = "AllowInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.app[each.key].function_name
  principal                = "*"
  invoked_via_function_url = true
}