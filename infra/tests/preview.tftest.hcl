mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "eu-north-1"
    }
  }
}

run "opennext_build" {
  command = plan

  module {
    source = "./modules/nextjs"
  }

  variables {
    name          = "deploy-aws-pr-123"
    build_path    = "../.open-next"
    force_destroy = true
  }

  assert {
    condition     = length(data.archive_file.function) == 4 && length(aws_s3_object.assets) > 0 && length(aws_s3_object.cache) > 0
    error_message = "OpenNext must provide four Lambda packages, assets and initial ISR cache."
  }

  assert {
    condition     = aws_cloudfront_distribution.app.default_cache_behavior[0].target_origin_id == "server" && contains(aws_cloudfront_distribution.app.default_cache_behavior[0].allowed_methods, "POST")
    error_message = "SSR, API routes and Server Actions must reach the server, including POST requests."
  }

  assert {
    condition     = aws_cloudfront_distribution.app.ordered_cache_behavior[0].target_origin_id == "image" && aws_cloudfront_distribution.app.ordered_cache_behavior[1].target_origin_id == "assets"
    error_message = "Images must reach the optimizer and hashed assets must reach S3."
  }

  assert {
    condition     = aws_cloudfront_distribution.app.viewer_certificate[0].cloudfront_default_certificate && aws_cloudfront_cache_policy.server.min_ttl == 0 && aws_cloudfront_cache_policy.server.parameters_in_cache_key_and_forwarded_to_origin[0].cookies_config[0].cookie_behavior == "all"
    error_message = "Previews must work without ACM and must not share personalized cache entries."
  }

  assert {
    condition     = aws_sqs_queue.revalidation.fifo_queue && aws_sqs_queue.revalidation.visibility_timeout_seconds >= 6 * aws_lambda_function.app["revalidation"].timeout
    error_message = "ISR requires a FIFO queue with a visibility timeout covering Lambda retries."
  }
}

run "without_local_build" {
  command = plan

  module {
    source = "./modules/nextjs"
  }

  variables {
    name             = "deploy-aws-pr-123"
    build_path       = "/nonexistent/opennext-build"
    deploy_artifacts = false
    force_destroy    = true
  }

  assert {
    condition     = length(data.archive_file.function) == 0 && length(aws_s3_object.assets) == 0 && length(aws_s3_object.cache) == 0 && length(aws_lambda_invocation.initialize_cache) == 0
    error_message = "Cleanup configuration must not read local artifacts or invoke the cache initializer."
  }

  assert {
    condition     = length(aws_lambda_function.app) == 4 && aws_s3_bucket.app.force_destroy
    error_message = "Cleanup must retain resource addresses and permit removal of runtime cache objects."
  }
}

run "application_slug_isolation" {
  command = plan

  variables {
    app_slug            = "another-app"
    pr_number           = "123"
    opennext_build_path = "/nonexistent/opennext-build"
    deploy_artifacts    = false
  }

  assert {
    condition     = module.nextjs.s3_bucket_name == "another-app-pr-123-123456789012-eu-north-1"
    error_message = "The app slug must isolate preview buckets across consuming repositories."
  }
}