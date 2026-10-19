resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "${var.name}-assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "forward_host" {
  name    = "${var.name}-forward-host"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      request.headers["x-forwarded-host"] = request.headers.host;
      return request;
    }
  JS
}

data "aws_cloudfront_cache_policy" "static" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "server" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_cache_policy" "server" {
  name        = "${var.name}-server"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "all"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["accept", "rsc", "next-router-prefetch", "next-router-state-tree", "next-url", "x-prerender-revalidate"]
      }
    }

    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "app" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  price_class     = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.app.bucket_regional_domain_name
    origin_id                = "assets"
    origin_path              = "/_assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  dynamic "origin" {
    for_each = aws_lambda_function_url.app

    content {
      domain_name = trimsuffix(trimprefix(origin.value.function_url, "https://"), "/")
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
        origin_read_timeout    = 30
      }
    }
  }

  default_cache_behavior {
    target_origin_id         = "server"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.server.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.server.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.forward_host.arn
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/_next/image*"
    target_origin_id         = "image"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.server.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.server.id
  }

  ordered_cache_behavior {
    path_pattern           = "/_next/static/*"
    target_origin_id       = "assets"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.static.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_lambda_permission.url, aws_lambda_permission.invoke, aws_s3_object.assets, aws_lambda_invocation.initialize_cache]
}