terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  functions = {
    server       = "server-functions/default"
    image        = "image-optimization-function"
    revalidation = "revalidation-function"
    initializer  = "dynamodb-provider"
  }
  cache_environment = {
    CACHE_BUCKET_NAME         = aws_s3_bucket.app.bucket
    CACHE_BUCKET_KEY_PREFIX   = "_cache"
    CACHE_BUCKET_REGION       = data.aws_region.current.region
    CACHE_DYNAMO_TABLE        = aws_dynamodb_table.cache.name
    REVALIDATION_QUEUE_URL    = aws_sqs_queue.revalidation.url
    REVALIDATION_QUEUE_REGION = data.aws_region.current.region
  }
}