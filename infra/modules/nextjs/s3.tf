resource "aws_s3_bucket" "app" {
  bucket        = "${var.name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

locals {
  asset_files = var.deploy_artifacts ? fileset("${var.build_path}/assets", "**") : toset([])
  cache_files = var.deploy_artifacts ? fileset("${var.build_path}/cache", "**") : toset([])
  content_types = {
    css   = "text/css"
    html  = "text/html"
    ico   = "image/x-icon"
    jpeg  = "image/jpeg"
    jpg   = "image/jpeg"
    js    = "application/javascript"
    json  = "application/json"
    png   = "image/png"
    svg   = "image/svg+xml"
    txt   = "text/plain"
    webp  = "image/webp"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }
}

resource "aws_s3_object" "assets" {
  for_each = local.asset_files

  bucket        = aws_s3_bucket.app.id
  key           = "_assets/${each.value}"
  source        = "${var.build_path}/assets/${each.value}"
  source_hash   = filemd5("${var.build_path}/assets/${each.value}")
  content_type  = lookup(local.content_types, element(split(".", each.value), length(split(".", each.value)) - 1), "application/octet-stream")
  cache_control = startswith(each.value, "_next/static/") ? "public,max-age=31536000,immutable" : "public,max-age=0,must-revalidate"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.app]
}

resource "aws_s3_object" "cache" {
  for_each = local.cache_files

  bucket      = aws_s3_bucket.app.id
  key         = "_cache/${each.value}"
  source      = "${var.build_path}/cache/${each.value}"
  source_hash = filemd5("${var.build_path}/cache/${each.value}")

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.app]
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.app.arn}/_assets/*"
        Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.app.arn } }
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}