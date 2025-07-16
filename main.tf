##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  synthetics = merge([
    for group in var.groups : {
      for canary in group.canaries : "${group.name}-${canary.name}" => {
        group             = group
        canary            = canary
        canary_final_name = format("synth-%s-%s", canary.name, local.system_name)
      }
    }
  ]...)
  synth_groups = {
    for group in var.groups : group.name => group
  }
  s3_location_bucket_name = var.create_artifacts_bucket ? module.synthetics_artifacts.s3_bucket_id : data.aws_s3_bucket.artifacts[0].bucket
}

data "aws_s3_bucket" "artifacts" {
  count  = var.create_artifacts_bucket ? 0 : 1
  bucket = var.artifacts_bucket
}

resource "aws_synthetics_group" "this" {
  for_each = local.synth_groups
  name     = format("group-%s-%s", each.value.name, local.system_name)
  tags = merge(
    local.all_tags,
    try(each.value.tags, {}),
    {
      synthetic_group_key = each.value.name
    }
  )
}

resource "aws_synthetics_canary" "this" {
  for_each                 = local.synthetics
  artifact_s3_location     = local.s3_location_bucket_name
  execution_role_arn       = aws_iam_role.this[each.value.group.name].arn
  name                     = each.value.canary_final_name
  start_canary             = try(each.value.canary.enabled, true)
  runtime_version          = try(each.value.canary.runtime_version, "syn-python-selenium-6.0")
  handler                  = try(each.value.canary.handler, "canary_handler.handler")
  delete_lambda            = !try(each.value.canary.preserve_lambda, false)
  success_retention_period = try(each.value.canary.success_retention_period, 1)
  failure_retention_period = try(each.value.canary.failure_retention_period, 1)
  #zip_file                 = format("%s%s", local.zip_files[each.key].file_path, local.zip_files[each.key].file_name)
  s3_bucket  = local.s3_location_bucket_name
  s3_key     = local.zip_files[each.key].bucket_key
  s3_version = aws_s3_object.script[each.key].version_id
  schedule {
    expression          = each.value.canary.schedule_expression
    duration_in_seconds = try(each.value.canary.schedule_duration, null)
  }
  vpc_config {
    subnet_ids         = var.vpc.subnet_ids
    security_group_ids = concat(var.vpc.security_group_ids, [aws_security_group.this[each.value.group.name].id])
  }

  run_config {
    environment_variables = merge({
      CONFIG_PATH = "./${local.zip_files[each.key].file_name}"
      },
      try(each.value.canary.run_config.environment_variables, {})
    )
    timeout_in_seconds = try(each.value.canary.run_config.timeout_in_seconds, null)
    memory_in_mb       = try(each.value.canary.run_config.memory_mb, null)
    active_tracing     = try(each.value.canary.run_config.tracing, null)
  }
  tags = merge(
    local.all_tags,
    try(each.value.group.tags, {}),
    try(each.value.canary.tags, {}),
    {
      synthetic_group_key  = each.value.group.name,
      synthetic_canary_key = each.value.canary.name
    }
  )
}

resource "aws_synthetics_group_association" "this" {
  for_each   = local.synthetics
  group_name = aws_synthetics_group.this[each.value.group.name].name
  canary_arn = aws_synthetics_canary.this[each.key].arn
}