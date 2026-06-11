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
  org              = jsondecode(file("tests/fixtures/strict-invalid-assertion.tfvars.json")).org
  vpc              = jsondecode(file("tests/fixtures/strict-invalid-assertion.tfvars.json")).vpc
  artifacts_bucket = jsondecode(file("tests/fixtures/strict-invalid-assertion.tfvars.json")).artifacts_bucket
  groups           = jsondecode(file("tests/fixtures/strict-invalid-assertion.tfvars.json")).groups
}

run "strict_invalid_assertion_fails" {
  command = plan

  expect_failures = [
    aws_synthetics_canary.this["strict-invalid-bad-assertion"]
  ]
}
