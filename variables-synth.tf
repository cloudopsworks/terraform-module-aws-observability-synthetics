##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

## Canaries configuration for AWS Synthetics - YAML format
# groups:
#   - name: "example-group"
#     tags:                # (optional) Tags for the group
#       Environment: "Production"
#     vpc:
#       enabled: true | false # (optional) Whether to enable VPC for the group, defaults to true
#       ipv6_allowed_for_dual_stack: true | false # (optional) Allow IPv6 for dual-stack VPC canaries, defaults to null
#     default_artifact_config:      # (optional) Default artifact encryption for canaries in the group
#       s3_encryption:
#         encryption_mode: "SSE_S3" | "SSE_KMS" # (optional) S3 artifact encryption mode, defaults to provider default
#         kms_key_arn: ""                       # (optional) KMS key ARN for SSE_KMS artifacts, defaults to null
#     default_run_config:         # (optional) Default run configuration for the group
#       environment_variables: {} # (optional) Environment variables for the canary, defaults to empty map
#       timeout: 60               # (optional) Timeout in seconds for the canary, defaults to null
#       memory_mb: 128            # (optional) Memory in MB for the canary, defaults to null
#       tracing: true | false     # (optional) Whether to enable xray tracing, defaults to null
#       ephemeral_storage_mb: 1024  # (optional) Ephemeral storage in MB for the canary runtime, defaults to provider default
#     default_schedule_retry:
#       max_retries: 2             # (optional) Max schedule retry attempts, defaults to provider default
#     validation_mode: "legacy" | "strict" # (optional) Request DSL validation mode for the group, defaults by request alias
#     canaries:           # List of canaries in the group
#       - name: "example-canary"
#         description: "This is an example canary" # (optional) Description of the canary
#         enabled: true | false # (optional) Whether the canary is enabled, defaults to true
#         tags:            # (optional) Tags for the canary
#           Environment: "Production"
#         preserve_lambda: true | false # (optional) Whether to preserve the Lambda function after deletion, defaults to false
#         runtime_version: ""           # (optional) AWS Synthetics runtime version; defaults by requests_type:
#                                       #   URL      → syn-python-selenium-11.0  (handler: canary_handler.handler)
#                                       #   API      → syn-nodejs-puppeteer-16.0 (handler: canary_handler.handler)
#                                       #   JSURL    → syn-nodejs-puppeteer-16.0 (handler: canary_handler.handler)
#                                       #   TRACEURL → syn-nodejs-puppeteer-16.0 (handler: trace_canary_handler.handler)
#                                       #   SCRIPT   → syn-nodejs-puppeteer-16.0 (handler: custom_handler.handler)
#         handler: ""                   # (optional) Override the canary handler function; defaults per requests_type above
#         validation_mode: "legacy" | "strict" # (optional) Request DSL validation mode, defaults by request alias
#         artifact_config:              # (optional) Artifact encryption override for this canary
#           s3_encryption:
#             encryption_mode: "SSE_S3" | "SSE_KMS" # (optional) S3 artifact encryption mode
#             kms_key_arn: ""                       # (optional) KMS key ARN for SSE_KMS artifacts
#         schedule_expression: "rate(5 minutes)" # (optional) Schedule for the canary, defaults to "rate(5 minutes)" or cron expression "cron(0/5 * * * ? *)"
#         schedule_duration: 300 # (optional) Duration in seconds for the canary schedule, defaults to null
#         schedule_retry:
#           max_retries: 2      # (optional) Max schedule retry attempts, defaults to group/module/provider default
#         success_retention_period: 7 # (optional) Retention period in Days for successful runs, defaults to 1 Day
#         failure_retention_period: 7 # (optional) Retention period in Days for failed runs, defaults to 1 Day
#         requests_type: "URL" | "SCRIPT" | "API" | "JSURL" | "TRACEURL" | "HTTP" | "HTTP_API" | "BROWSER_URL" | "BROWSER_SCRIPT" # (required) Type of request, defaults to URL
#         request_script: |                      # (optional) Script for the canary, required if type is SCRIPT
#         request_script_ref: "script-name" # (optional) Reference to a script defined in request_scripts; when set, runtime_version and handler are inherited from the referenced script
#         requests:
#           - url: "https://example.com"    # (optional) URL for the canary, required if type is URL
#             script: "path/to/script.js"   # (optional) Path to the script for the canary, required if type is SCRIPT
#             timeout: 30                   # (optional) Timeout in seconds for the request, defaults to 30 seconds
#             method: GET | POST | PUT | DELETE # (optional) HTTP method for the request, defaults to GET
#             headers:                     # (optional) Headers for the request, defaults to empty map
#               Content-Type: "application/json"
#             body: "request body"         # (optional) Body for the request, required if method is POST or PUT
#             assertions:                # (optional) Assertions for the canary, defaults to empty list
#               - type: STATUS_CODE # (required) Type of assertion, e.g., STATUS_CODE, RESPONSE_TIME, etc.
#                 operator: EQUALS | NOT_EQUALS | GREATER_THAN | LESS_THAN # (required) Operator for the assertion
#                 value: 200 # (required) Value for the assertion, e.g., expected status code
#             retry:
#               count: 3 # (optional) Number of retry attempts, defaults to 3
#               interval: 5 # (optional) Interval in seconds between retries, defaults to 5 seconds
#         run_config:
#           environment_variables: {} # (optional) Environment variables for the canary, defaults to empty map
#           timeout: 60               # (optional) Timeout in seconds for the canary, defaults to null
#           memory_mb: 128            # (optional) Memory in MB for the canary, defaults to null
#           tracing: true | false     # (optional) Whether to enable xray tracing, defaults to null
#           ephemeral_storage_mb: 1024  # (optional) Ephemeral storage in MB for the canary runtime, defaults to provider default
#         alarms:                 # (optional) Alarms configuration for the canary
#           enabled: true | false # (optional) Whether to create alarms for the canary, defaults to true
#           priority: 1           # (optional) Priority of the alarms, defaults to 4
#           description: "This alarm is triggered when the canary fails." # (optional) Description of the alarm, defaults to a generic message
#           evaluation_periods: "1" # (optional) Number of evaluation periods for the alarm, defaults to 1
#           period: "900"          # (optional) Period in seconds for the alarm, defaults to 900 seconds (15minutes)
#           threshold: "90"       # (optional) Threshold for the alarm, defaults to 90% SuccessPercent
#           metric: "SuccessPercent" | "Failure" | "Duration" # (optional) Metric for the alarm, defaults to "SuccessPercent"
#           condition: "GreaterThanOrEqualToThreshold" | "GreaterThanThreshold" | "LessThanThreshold" | "LessThanThreshold" # (optional) Condition for the alarm, defaults to "GreaterThanOrEqualToThreshold"
#           statistic: "Average" | "Sum" | "Minimum" | "Maximum" # (optional) Statistic for the alarm, defaults to "Average"
#           notifications: # (optional) Notification settings for the alarm
#             - sns_topic_name: "topic-name" # (optional) Name of the SNS topic for notifications
#             - sns_topic_arn: "topic-name" # (optional) ARN of the SNS topic for notifications
variable "groups" {
  description = "Settings for the synthetics configurations"
  type        = any
  default     = []

  validation {
    condition = alltrue(flatten([
      for group in var.groups : [
        for canary in try(group.canaries, []) : contains(
          ["URL", "SCRIPT", "API", "JSURL", "TRACEURL", "HTTP", "HTTP_API", "BROWSER_URL", "BROWSER_SCRIPT"],
          upper(coalesce(try(canary.requests_type, null), "URL"))
        )
      ]
    ]))
    error_message = "Each canary requests_type must be one of URL, SCRIPT, API, JSURL, TRACEURL, HTTP, HTTP_API, BROWSER_URL, or BROWSER_SCRIPT."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.groups : concat(
        [
          contains(["legacy", "strict"], lower(coalesce(try(group.validation_mode, null), "legacy")))
        ],
        [
          for canary in try(group.canaries, []) : contains(["legacy", "strict"], lower(coalesce(try(canary.validation_mode, null), "legacy")))
        ]
      )
    ]))
    error_message = "validation_mode must be legacy or strict when set at group or canary level."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.groups : concat(
        [
          coalesce(try(group.default_schedule_retry.max_retries, null), 0) >= 0
        ],
        [
          for canary in try(group.canaries, []) : coalesce(try(canary.schedule_retry.max_retries, null), 0) >= 0
        ]
      )
    ]))
    error_message = "schedule_retry.max_retries must be greater than or equal to 0 when set."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.groups : concat(
        [
          coalesce(try(group.default_run_config.ephemeral_storage_mb, null), 1024) >= 1024
        ],
        [
          for canary in try(group.canaries, []) : coalesce(try(canary.run_config.ephemeral_storage_mb, null), 1024) >= 1024
        ]
      )
    ]))
    error_message = "run_config.ephemeral_storage_mb must be at least 1024 MB when set."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.groups : concat(
        [
          try(contains(["SSE_S3", "SSE_KMS"], upper(group.default_artifact_config.s3_encryption.encryption_mode)), true)
        ],
        [
          for canary in try(group.canaries, []) : try(contains(["SSE_S3", "SSE_KMS"], upper(canary.artifact_config.s3_encryption.encryption_mode)), true)
        ]
      )
    ]))
    error_message = "artifact_config.s3_encryption.encryption_mode must be SSE_S3 or SSE_KMS when set."
  }
}

variable "default_sns_topic_name" {
  description = "(optional) Name of the SNS topic for notifications, defaults to empty string"
  type        = string
  default     = ""
  nullable    = false
}

variable "create_alarms" {
  description = "(optional) Flag to create CloudWatch alarms for the Synthetics canaries, defaults to true"
  type        = bool
  default     = true
}

variable "alarms_defaults" {
  description = "(optional) Default settings for CloudWatch alarms"
  type = object({
    enabled            = optional(bool, true)
    evaluation_periods = optional(string, "1")
    period             = optional(string, "900")
    threshold          = optional(string, "90")
    metric             = optional(string, "SuccessPercent")
    condition          = optional(string, "LessThanThreshold")
    description        = optional(string, "This alarm is triggered when the canary fails.")
  })
  default = {}
}

variable "request_scripts" {
  description = "(optional) Array of request scripts for the Synthetics canaries"
  type = list(object({
    name            = string
    content         = string
    runtime_version = string
    handler         = optional(string, "custom_handler.handler")
  }))
  default = []
}

variable "vpc" {
  description = "(required) VPC configuration for the Synthetics canaries"
  type = object({
    enabled                     = optional(bool, true)
    vpc_id                      = optional(string, "")
    subnet_ids                  = optional(list(string), [])
    security_group_ids          = optional(list(string), [])
    ipv6_allowed_for_dual_stack = optional(bool)
  })
}

variable "canary_defaults" {
  description = "(optional) Module-level defaults for Synthetics canary provider options and validation behavior"
  type = object({
    validation_mode = optional(string)
    artifact_config = optional(object({
      s3_encryption = optional(object({
        encryption_mode = optional(string)
        kms_key_arn     = optional(string)
      }))
    }), {})
    run_config = optional(object({
      ephemeral_storage_mb = optional(number)
    }), {})
    schedule_retry = optional(object({
      max_retries = optional(number)
    }), {})
    vpc = optional(object({
      ipv6_allowed_for_dual_stack = optional(bool)
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["legacy", "strict"], lower(coalesce(try(var.canary_defaults.validation_mode, null), "legacy")))
    error_message = "canary_defaults.validation_mode must be either legacy or strict when set."
  }

  validation {
    condition     = try(contains(["SSE_S3", "SSE_KMS"], upper(var.canary_defaults.artifact_config.s3_encryption.encryption_mode)), true)
    error_message = "canary_defaults.artifact_config.s3_encryption.encryption_mode must be SSE_S3 or SSE_KMS when set."
  }

  validation {
    condition     = coalesce(try(var.canary_defaults.schedule_retry.max_retries, null), 0) >= 0
    error_message = "canary_defaults.schedule_retry.max_retries must be greater than or equal to 0 when set."
  }

  validation {
    condition     = coalesce(try(var.canary_defaults.run_config.ephemeral_storage_mb, null), 1024) >= 1024
    error_message = "canary_defaults.run_config.ephemeral_storage_mb must be at least 1024 MB when set."
  }
}

variable "artifact_output_prefix" {
  description = "(optional) Prefix under the artifacts bucket for AWS Synthetics run artifacts, defaults to the bucket root"
  type        = string
  default     = ""
  nullable    = false
}

variable "code_package_prefix" {
  description = "(optional) Prefix under the artifacts bucket for uploaded canary code packages, defaults to upload/scripts"
  type        = string
  default     = "upload/scripts"
  nullable    = false

  validation {
    condition     = trim(var.code_package_prefix, "/") != ""
    error_message = "code_package_prefix must not be empty after trimming leading and trailing slashes."
  }
}

variable "artifacts_bucket" {
  description = "(optional) S3 bucket for storing Synthetics canary artifacts"
  type        = string
  default     = ""
  nullable    = false
}

variable "create_artifacts_bucket" {
  description = "(optional) Flag to create the S3 bucket for Synthetics canary artifacts, required if artifacts_bucket is not provided"
  type        = bool
  default     = false
}
