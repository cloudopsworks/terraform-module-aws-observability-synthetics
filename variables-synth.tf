##
# (c) 2021-2025
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
#     default_run_config:         # (optional) Default run configuration for the group
#       environment_variables: {} # (optional) Environment variables for the canary, defaults to empty map
#       timeout: 60               # (optional) Timeout in seconds for the canary, defaults to null
#       memory_mb: 128            # (optional) Memory in MB for the canary, defaults to null
#       tracing: true | false     # (optional) Whether to enable xray tracing, defaults to null
#     canaries:           # List of canaries in the group
#       - name: "example-canary"
#         description: "This is an example canary" # (optional) Description of the canary
#         enabled: true | false # (optional) Whether the canary is enabled, defaults to true
#         tags:            # (optional) Tags for the canary
#           Environment: "Production"
#         preserve_lambda: true | false # (optional) Whether to preserve the Lambda function after deletion, defaults to false
#         runtime_version: "syn-python-selenium-6.0"
#         schedule_expression: "rate(5 minutes)" # (optional) Schedule for the canary, defaults to "rate(5 minutes)" or cron expression "cron(0/5 * * * ? *)"
#         schedule_duration: 300 # (optional) Duration in seconds for the canary schedule, defaults to null
#         success_retention_period: 7 # (optional) Retention period in Days for successful runs, defaults to 1 Day
#         failure_retention_period: 7 # (optional) Retention period in Days for failed runs, defaults to 1 Day
#         requests_type: "URL" | "SCRIPT" | "API" # (required) Type of request, defaults to URL
#         request_script: |                      # (optional) Script for the canary, required if type is SCRIPT
#         request_script_ref: "script-name" # (optional) Reference to the script for the canary, required if type is SCRIPT and request_script is not provided
#         requests:
#           - url: "https://example.com"    # (optional) URL for the canary, required if type is URL
#             script: "path/to/script.js"   # (optional) Path to the script for the canary, required if type is SCRIP
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
  }))
  default = []
}

variable "vpc" {
  description = "(required) VPC configuration for the Synthetics canaries"
  type = object({
    enabled            = optional(bool, true)
    vpc_id             = optional(string, "")
    subnet_ids         = optional(list(string), [])
    security_group_ids = optional(list(string), [])
  })
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