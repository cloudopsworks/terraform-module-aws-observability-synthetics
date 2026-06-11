mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::example-synthetics-artifacts"
    }
  }
  mock_data "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:example-alerts"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/example-synthetics"
    }
  }
}

mock_provider "local" {}
mock_provider "null" {}
mock_provider "random" {}

variables {
  org                    = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).org
  spoke_def              = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).spoke_def
  vpc                    = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).vpc
  artifacts_bucket       = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).artifacts_bucket
  artifact_output_prefix = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).artifact_output_prefix
  code_package_prefix    = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).code_package_prefix
  create_alarms          = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).create_alarms
  default_sns_topic_name = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).default_sns_topic_name
  canary_defaults        = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).canary_defaults
  request_scripts        = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).request_scripts
  groups                 = jsondecode(file("tests/fixtures/generic-consumers.tfvars.json")).groups
}

run "generic_consumers_plan" {
  command = plan

  assert {
    condition     = length(aws_synthetics_canary.this) == 5
    error_message = "Expected generic fixture to produce five canaries."
  }

  assert {
    condition     = aws_synthetics_canary.this["consumer-a-script-ref"].handler == "custom_handler.handler"
    error_message = "Reusable script handler should be inherited for Consumer A script-ref."
  }

  assert {
    condition     = aws_synthetics_canary.this["consumer-a-script-inline"].handler == "inline_handler.handler"
    error_message = "Per-canary handler should override default handler for Consumer A inline script."
  }

  assert {
    condition     = aws_synthetics_canary.this["consumer-b-service-health"].runtime_version == "syn-nodejs-puppeteer-16.0"
    error_message = "TRACEURL should retain the Node.js Synthetics runtime."
  }

  assert {
    condition     = aws_synthetics_canary.this["consumer-c-private-post"].artifact_s3_location == "s3://example-synthetics-artifacts/synthetics/artifacts"
    error_message = "Artifact output prefix should be appended to artifact_s3_location."
  }

  assert {
    condition     = aws_synthetics_canary.this["consumer-c-private-post"].s3_key == "synthetics/packages/consumer-c-private-post.zip"
    error_message = "Code package prefix should be applied to canary package keys."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.canary_failed["consumer-a-script-inline"].alarm_actions) == 2
    error_message = "Consumer A script-inline should include its own SNS topic ARN plus the default topic."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.canary_failed["consumer-b-service-health"].alarm_actions) == 1
    error_message = "Consumer B alarm should not inherit Consumer A notification topics."
  }
}
