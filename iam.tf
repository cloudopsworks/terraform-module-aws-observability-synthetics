##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_caller_identity" "current" {}

# Assume role policy for Synthetics canaries
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

data "aws_iam_policy_document" "synthetic_policy" {
  for_each = local.synth_groups
  statement {
    sid    = "AllowS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      var.create_artifacts_bucket ? local.created_artifacts_bucket : data.aws_s3_bucket.artifacts[0].arn,
      "${var.create_artifacts_bucket ? local.created_artifacts_bucket : data.aws_s3_bucket.artifacts[0].arn}/canary/${data.aws_region.current.id}/*"
    ]
  }
  statement {
    sid    = "AllowCloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
      "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*"
    ]
  }
  statement {
    sid    = "AllowSyntheticsXray"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    sid    = "AllowSynteticsMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values = [
        "CloudWatchSynthetics"
      ]
    }
  }
  statement {
    sid    = "AllowEC2attachment"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role" "this" {
  for_each           = local.synth_groups
  name               = format("synth-%s-%s-role", each.value.name, local.system_name_short)
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy" "synthetic_policy" {
  for_each = local.synth_groups
  role     = aws_iam_role.this[each.key].id
  policy   = data.aws_iam_policy_document.synthetic_policy[each.key].json
}