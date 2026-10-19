resource "aws_dynamodb_table" "cache" {
  name         = "${var.name}-cache"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tag"
  range_key    = "path"

  attribute {
    name = "tag"
    type = "S"
  }

  attribute {
    name = "path"
    type = "S"
  }

  attribute {
    name = "revalidatedAt"
    type = "N"
  }

  global_secondary_index {
    name            = "revalidate"
    projection_type = "ALL"

    key_schema {
      attribute_name = "path"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "revalidatedAt"
      key_type       = "RANGE"
    }
  }
}

resource "aws_sqs_queue" "dead_letter" {
  name                      = "${var.name}-revalidation-dlq.fifo"
  fifo_queue                = true
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "revalidation" {
  name                        = "${var.name}-revalidation.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  sqs_managed_sse_enabled     = true
  visibility_timeout_seconds  = 180
  receive_wait_time_seconds   = 20
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_event_source_mapping" "revalidation" {
  event_source_arn        = aws_sqs_queue.revalidation.arn
  function_name           = aws_lambda_function.app["revalidation"].arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_invocation" "initialize_cache" {
  count = var.deploy_artifacts ? 1 : 0

  function_name = aws_lambda_function.app["initializer"].function_name
  input         = jsonencode({ RequestType = "Create" })
  triggers = {
    code = data.archive_file.function["initializer"].output_base64sha256
  }

  depends_on = [aws_s3_object.cache]
}