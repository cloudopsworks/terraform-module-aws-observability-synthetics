##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

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
    sid    = "AllowS3ListBuckets"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
    ]
    # ListAllMyBuckets (ListBuckets API) is an account-level action and must use "*"
    resources = ["*"]
  }
  statement {
    sid    = "AllowS3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketAcl",
    ]
    resources = [
      var.create_artifacts_bucket ? "arn:${data.aws_partition.current.partition}:s3:::${local.created_artifacts_bucket}" : data.aws_s3_bucket.artifacts[0].arn,
    ]
  }
  statement {
    sid    = "AllowS3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = [
      "${var.create_artifacts_bucket ? "arn:${data.aws_partition.current.partition}:s3:::${local.created_artifacts_bucket}" : data.aws_s3_bucket.artifacts[0].arn}/${local.artifact_iam_path}",
      "${var.create_artifacts_bucket ? "arn:${data.aws_partition.current.partition}:s3:::${local.created_artifacts_bucket}" : data.aws_s3_bucket.artifacts[0].arn}/${local.code_package_prefix}/*",
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
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-*",
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-*:*"
    ]
  }
  dynamic "statement" {
    for_each = length(local.standard_synthetic_keys_by_group[each.key]) == 0 ? [] : [local.standard_synthetic_keys_by_group[each.key]]
    content {
      sid    = "AllowCanaryConfigRead"
      effect = "Allow"
      actions = [
        "ssm:GetParameter",
      ]
      resources = [
        for key in statement.value : local.canary_config_parameter_arns[key]
      ]
    }
  }
  dynamic "statement" {
    for_each = length(local.standard_synthetic_keys_by_group[each.key]) == 0 ? [] : [local.standard_synthetic_keys_by_group[each.key]]
    content {
      sid    = "AllowCanaryConfigDecryption"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
      ]
      resources = [
        "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/*",
      ]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values = [
          "ssm.${data.aws_region.current.region}.amazonaws.com",
        ]
      }
      condition {
        test     = "ForAnyValue:StringEquals"
        variable = "kms:EncryptionContext:PARAMETER_ARN"
        values = [
          for key in statement.value : local.canary_config_parameter_arns[key]
        ]
      }
    }
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
    sid    = "AllowSyntheticsMetrics"
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
      "ec2:DescribeVpcs",
      "ec2:DetachNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
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
  tags = merge(
    local.all_tags,
    try(each.value.tags, {}),
    {
      synthetic_group_key = each.key
    }
  )
}

resource "aws_iam_role_policy" "synthetic_policy" {
  for_each = local.synth_groups
  role     = aws_iam_role.this[each.key].id
  name     = format("synth-%s-%s-policy", each.value.name, local.system_name_short)
  policy   = data.aws_iam_policy_document.synthetic_policy[each.key].json
}
