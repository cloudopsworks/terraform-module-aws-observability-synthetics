##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  request_type_alias_map = {
    HTTP           = "URL"
    HTTP_API       = "API"
    BROWSER_URL    = "JSURL"
    BROWSER_SCRIPT = "SCRIPT"
  }
  strict_request_type_aliases = keys(local.request_type_alias_map)
  supported_validation_modes  = ["legacy", "strict"]
  supported_http_methods      = ["GET", "POST", "PUT", "DELETE"]
  supported_assertion_types   = ["STATUS_CODE", "RESPONSE_TIME"]
  supported_assertion_ops     = ["EQUALS", "NOT_EQUALS", "GREATER_THAN", "LESS_THAN"]

  artifact_output_prefix = trim(var.artifact_output_prefix, "/")
  code_package_prefix    = trim(var.code_package_prefix, "/")
  artifact_s3_location   = local.artifact_output_prefix == "" ? "s3://${local.s3_location_bucket_name}" : "s3://${local.s3_location_bucket_name}/${local.artifact_output_prefix}"
  artifact_iam_path      = local.artifact_output_prefix == "" ? "canary/${data.aws_region.current.region}/*" : "${local.artifact_output_prefix}/canary/${data.aws_region.current.region}/*"

  script_configuration_map = {
    URL = {
      handler         = "canary_handler.handler"
      runtime_version = "syn-python-selenium-11.0"
      is_custom       = false
    }
    SCRIPT = {
      handler         = "custom_handler.handler"
      runtime_version = "syn-nodejs-puppeteer-16.0"
      is_custom       = true
    }
    API = {
      handler         = "canary_handler.handler"
      runtime_version = "syn-nodejs-puppeteer-16.0"
      is_custom       = false
    }
    JSURL = {
      handler         = "canary_handler.handler"
      runtime_version = "syn-nodejs-puppeteer-16.0"
      is_custom       = false
    }
    TRACEURL = {
      handler         = "trace_canary_handler.handler"
      runtime_version = "syn-nodejs-puppeteer-16.0"
      is_custom       = false
    }
  }
  request_scripts_map = {
    for script in var.request_scripts : script.name => {
      name            = script.name
      content         = script.content
      handler         = try(script.handler, "") != "" ? script.handler : "custom_handler.handler"
      runtime_version = script.runtime_version
    }
  }
  synthetics_base = merge([
    for group in var.groups : {
      for canary in group.canaries : "${group.name}-${canary.name}" => {
        group             = group
        canary            = canary
        canary_final_name = format("synth-%s-%s", canary.name, local.system_name)
        raw_request_type  = upper(coalesce(try(canary.requests_type, null), "URL"))
        request_type      = lookup(local.request_type_alias_map, upper(coalesce(try(canary.requests_type, null), "URL")), upper(coalesce(try(canary.requests_type, null), "URL")))
        validation_mode = lower(coalesce(
          try(canary.validation_mode != "" ? canary.validation_mode : null, null),
          try(group.validation_mode != "" ? group.validation_mode : null, null),
          try(var.canary_defaults.validation_mode != "" ? var.canary_defaults.validation_mode : null, null),
          contains(local.strict_request_type_aliases, upper(coalesce(try(canary.requests_type, null), "URL"))) ? "strict" : "legacy"
        ))
        schedule_max_retries = try(coalesce(
          try(canary.schedule_retry.max_retries, null),
          try(group.default_schedule_retry.max_retries, null),
          try(var.canary_defaults.schedule_retry.max_retries, null)
        ), null)
        run_ephemeral_storage_mb = try(coalesce(
          try(canary.run_config.ephemeral_storage_mb, null),
          try(group.default_run_config.ephemeral_storage_mb, null),
          try(var.canary_defaults.run_config.ephemeral_storage_mb, null)
        ), null)
        vpc_ipv6_allowed_dual_stack = try(coalesce(
          try(canary.vpc.ipv6_allowed_for_dual_stack, null),
          try(group.vpc.ipv6_allowed_for_dual_stack, null),
          try(var.canary_defaults.vpc.ipv6_allowed_for_dual_stack, null),
          try(var.vpc.ipv6_allowed_for_dual_stack, null)
        ), null)
        artifact_s3_encryption = try(coalesce(
          try(canary.artifact_config.s3_encryption, null),
          try(group.default_artifact_config.s3_encryption, null),
          try(var.canary_defaults.artifact_config.s3_encryption, null)
        ), null)
        artifact_s3_encryption_enabled = (
          try(coalesce(
            try(canary.artifact_config.s3_encryption.encryption_mode, null),
            try(group.default_artifact_config.s3_encryption.encryption_mode, null),
            try(var.canary_defaults.artifact_config.s3_encryption.encryption_mode, null)
          ), null) != null ||
          try(coalesce(
            try(canary.artifact_config.s3_encryption.kms_key_arn, null),
            try(group.default_artifact_config.s3_encryption.kms_key_arn, null),
            try(var.canary_defaults.artifact_config.s3_encryption.kms_key_arn, null)
          ), null) != null
        )
      }
    }
  ]...)
  synthetics_runtime_versions = {
    for key, synthetic in local.synthetics_base : key => coalesce(
      try(local.request_scripts_map[synthetic.canary.request_script_ref].runtime_version != "" ? local.request_scripts_map[synthetic.canary.request_script_ref].runtime_version : null, null),
      try(synthetic.canary.runtime_version != "" ? synthetic.canary.runtime_version : null, null),
      local.script_configuration_map[synthetic.request_type].runtime_version
    )
  }
  synthetics_handlers = {
    for key, synthetic in local.synthetics_base : key => coalesce(
      try(synthetic.canary.handler != "" ? synthetic.canary.handler : null, null),
      try(local.request_scripts_map[synthetic.canary.request_script_ref].handler != "" ? local.request_scripts_map[synthetic.canary.request_script_ref].handler : null, null),
      local.script_configuration_map[synthetic.request_type].handler
    )
  }
  synthetics = {
    for key, synthetic in local.synthetics_base : key => merge(synthetic, {
      script_configuration     = local.script_configuration_map[synthetic.request_type]
      resolved_runtime_version = local.synthetics_runtime_versions[key]
      resolved_handler         = local.synthetics_handlers[key]
      is_nodejs                = strcontains(local.synthetics_runtime_versions[key], "nodejs")
      is_python                = strcontains(local.synthetics_runtime_versions[key], "python")
    })
  }
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
  artifact_s3_location     = local.artifact_s3_location
  execution_role_arn       = aws_iam_role.this[each.value.group.name].arn
  name                     = each.value.canary_final_name
  start_canary             = try(each.value.canary.enabled, true)
  runtime_version          = each.value.resolved_runtime_version
  handler                  = each.value.resolved_handler
  delete_lambda            = !try(each.value.canary.preserve_lambda, false)
  success_retention_period = try(each.value.canary.success_retention_period, 1)
  failure_retention_period = try(each.value.canary.failure_retention_period, 1)
  s3_bucket                = local.s3_location_bucket_name
  s3_key                   = try(local.zip_files_nodejs[each.key].bucket_key, local.zip_files_python[each.key].bucket_key)
  s3_version               = try(aws_s3_object.script_url_nodejs[each.key].version_id, aws_s3_object.script_url_python[each.key].version_id, aws_s3_object.script_custom[each.key].version_id)
  schedule {
    expression          = try(each.value.canary.schedule_expression, "rate(5 minutes)")
    duration_in_seconds = try(each.value.canary.schedule_duration, null)

    dynamic "retry_config" {
      for_each = each.value.schedule_max_retries == null ? [] : [each.value.schedule_max_retries]
      content {
        max_retries = retry_config.value
      }
    }
  }
  dynamic "artifact_config" {
    for_each = each.value.artifact_s3_encryption_enabled ? [each.value.artifact_s3_encryption] : []
    content {
      s3_encryption {
        encryption_mode = try(artifact_config.value.encryption_mode, null)
        kms_key_arn     = try(artifact_config.value.kms_key_arn, null)
      }
    }
  }
  dynamic "vpc_config" {
    for_each = var.vpc.enabled && try(each.value.group.vpc.enabled, true) ? [1] : []
    content {
      subnet_ids                  = var.vpc.subnet_ids
      security_group_ids          = concat(var.vpc.security_group_ids, [aws_security_group.this[each.value.group.name].id])
      ipv6_allowed_for_dual_stack = each.value.vpc_ipv6_allowed_dual_stack
    }
  }

  run_config {
    environment_variables = merge(each.value.is_nodejs ? {
      CONFIG_PATH = "/opt/nodejs/${local.zip_files_nodejs[each.key].file_name}"
      } : {
      CONFIG_PATH = "/opt/python/${local.zip_files_python[each.key].file_name}"
      },
      try(each.value.group.default_run_config.environment_variables, {}),
      try(each.value.canary.run_config.environment_variables, {})
    )
    timeout_in_seconds = try(each.value.canary.run_config.timeout, each.value.group.default_run_config.timeout, null)
    memory_in_mb       = try(each.value.canary.run_config.memory_mb, each.value.group.default_run_config.memory_mb, null)
    active_tracing     = try(each.value.canary.run_config.tracing, each.value.group.default_run_config.tracing, null)
    ephemeral_storage  = each.value.run_ephemeral_storage_mb
  }
  tags = merge(
    local.all_tags,
    try(each.value.group.tags, {}),
    try(each.value.canary.tags, {}),
    {
      synthetic-group-key  = each.value.group.name,
      synthetic-canary-key = each.value.canary.name
    }
  )
  lifecycle {
    precondition {
      condition     = contains(local.supported_validation_modes, each.value.validation_mode)
      error_message = "validation_mode must be legacy or strict."
    }
    precondition {
      condition     = contains(keys(local.script_configuration_map), each.value.request_type)
      error_message = "requests_type must be one of URL, SCRIPT, API, JSURL, TRACEURL, HTTP, HTTP_API, BROWSER_URL, or BROWSER_SCRIPT."
    }
    precondition {
      condition = each.value.validation_mode == "legacy" || alltrue([
        for request in try(each.value.canary.requests, []) : (
          contains(local.supported_http_methods, upper(coalesce(try(request.method, null), "GET"))) &&
          coalesce(try(request.timeout, null), 30) > 0 &&
          coalesce(try(request.retry.count, null), 3) >= 1 &&
          coalesce(try(request.retry.interval, null), 5) >= 0 &&
          (!contains(["POST", "PUT"], upper(coalesce(try(request.method, null), "GET"))) || try(request.body, null) != null) &&
          alltrue([
            for assertion in try(request.assertions, []) : (
              contains(local.supported_assertion_types, upper(coalesce(try(assertion.type, null), ""))) &&
              contains(local.supported_assertion_ops, upper(coalesce(try(assertion.operator, null), ""))) &&
              try(assertion.value, null) != null
            )
          ])
        )
      ])
      error_message = "Strict validation requires supported methods, positive timeouts, retry.count >= 1, retry.interval >= 0, POST/PUT bodies, and supported assertions."
    }
  }
}

resource "aws_synthetics_group_association" "this" {
  for_each   = local.synthetics
  group_name = aws_synthetics_group.this[each.value.group.name].name
  canary_arn = aws_synthetics_canary.this[each.key].arn
}
