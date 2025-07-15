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
#     canaries:           # List of canaries in the group
#       - name: "example-canary"
#         enabled: true | false # (optional) Whether the canary is enabled, defaults to true
#         tags:            # (optional) Tags for the canary
#           Environment: "Production"
#         preserve_lambda: true | false # (optional) Whether to preserve the Lambda function after deletion, defaults to false
#         runtime_version: "syn-python-selenium-6.0"
#         schedule_expression: "rate(5 minutes)" # (optional) Schedule for the canary, defaults to "rate(5 minutes)" or cron expression "cron(0/5 * * * ? *)"
#         schedule_duration: 300 # (optional) Duration in seconds for the canary schedule, defaults to null
#         success_retention_period: 7 # (optional) Retention period in Days for successful runs, defaults to 1 Day
#         failure_retention_period: 7 # (optional) Retention period in Days for failed runs, defaults to 1 Day
#         requests_type: URL | API | SCRIPT      # (required) Type of request, defaults to URL
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
#           timeout_in_seconds: 60 # (optional) Timeout in seconds for the canary, defaults to null
#           memory_mb: 128 # (optional) Memory in MB for the canary, defaults to null
#           active_tracing: true | false # (optional) Whether to enable xray tracing, defaults to null
variable "groups" {
  description = "Settings for the synthetics configurations"
  type        = any
  default     = []
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  type        = string
  default     = ""
  nullable    = false
}

variable "create_alarms" {
  description = "Flag to create CloudWatch alarms for the Synthetics canaries"
  type        = bool
  default     = true
}

variable "vpc" {
  description = "VPC configuration for the Synthetics canaries"
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = optional(list(string), [])
  })
}

variable "artifacts_bucket" {
  description = "S3 bucket for storing Synthetics canary artifacts"
  type        = string
  default     = ""
  nullable    = false
}

variable "create_artifacts_bucket" {
  description = "Flag to create the S3 bucket for Synthetics canary artifacts"
  type        = bool
  default     = false
}