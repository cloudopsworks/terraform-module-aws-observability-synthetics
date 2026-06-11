## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.4 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.4 |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.5 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.5 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_synthetics_artifacts"></a> [synthetics\_artifacts](#module\_synthetics\_artifacts) | terraform-aws-modules/s3-bucket/aws | ~> 5.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | cloudopsworks/tags/local | 1.0.9 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_metric_alarm.canary_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ec2_tag.synthetic_enis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.synthetic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3_object.script_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.script_url_nodejs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.script_url_python](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_synthetics_canary.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/synthetics_canary) | resource |
| [aws_synthetics_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/synthetics_group) | resource |
| [aws_synthetics_group_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/synthetics_group_association) | resource |
| [local_file.script_config_nodejs](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.script_config_python](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.script_custom_node](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.script_custom_python](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.archive_url_nodejs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.archive_url_python](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.stage_nodejs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.stage_python](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.random](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [terraform_data.script_custom_node](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.script_custom_python](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.synthetic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_network_interfaces.synthetic_enis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/network_interfaces) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |
| [aws_sns_topic.default_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/sns_topic) | data source |
| [aws_sns_topic.topics_by_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/sns_topic) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarms_defaults"></a> [alarms\_defaults](#input\_alarms\_defaults) | (optional) Default settings for CloudWatch alarms | <pre>object({<br/>    enabled            = optional(bool, true)<br/>    evaluation_periods = optional(string, "1")<br/>    period             = optional(string, "900")<br/>    threshold          = optional(string, "90")<br/>    metric             = optional(string, "SuccessPercent")<br/>    condition          = optional(string, "LessThanThreshold")<br/>    description        = optional(string, "This alarm is triggered when the canary fails.")<br/>  })</pre> | `{}` | no |
| <a name="input_artifact_output_prefix"></a> [artifact\_output\_prefix](#input\_artifact\_output\_prefix) | (optional) Prefix under the artifacts bucket for AWS Synthetics run artifacts, defaults to the bucket root | `string` | `""` | no |
| <a name="input_artifacts_bucket"></a> [artifacts\_bucket](#input\_artifacts\_bucket) | (optional) S3 bucket for storing Synthetics canary artifacts | `string` | `""` | no |
| <a name="input_canary_defaults"></a> [canary\_defaults](#input\_canary\_defaults) | (optional) Module-level defaults for Synthetics canary provider options and validation behavior | <pre>object({<br/>    validation_mode = optional(string)<br/>    artifact_config = optional(object({<br/>      s3_encryption = optional(object({<br/>        encryption_mode = optional(string)<br/>        kms_key_arn     = optional(string)<br/>      }))<br/>    }), {})<br/>    run_config = optional(object({<br/>      ephemeral_storage_mb = optional(number)<br/>    }), {})<br/>    schedule_retry = optional(object({<br/>      max_retries = optional(number)<br/>    }), {})<br/>    vpc = optional(object({<br/>      ipv6_allowed_for_dual_stack = optional(bool)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_code_package_prefix"></a> [code\_package\_prefix](#input\_code\_package\_prefix) | (optional) Prefix under the artifacts bucket for uploaded canary code packages, defaults to upload/scripts | `string` | `"upload/scripts"` | no |
| <a name="input_create_alarms"></a> [create\_alarms](#input\_create\_alarms) | (optional) Flag to create CloudWatch alarms for the Synthetics canaries, defaults to true | `bool` | `true` | no |
| <a name="input_create_artifacts_bucket"></a> [create\_artifacts\_bucket](#input\_create\_artifacts\_bucket) | (optional) Flag to create the S3 bucket for Synthetics canary artifacts, required if artifacts\_bucket is not provided | `bool` | `false` | no |
| <a name="input_default_sns_topic_name"></a> [default\_sns\_topic\_name](#input\_default\_sns\_topic\_name) | (optional) Name of the SNS topic for notifications, defaults to empty string | `string` | `""` | no |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Extra tags to add to the resources | `map(string)` | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Settings for the synthetics configurations | `any` | `[]` | no |
| <a name="input_is_hub"></a> [is\_hub](#input\_is\_hub) | Is this a hub or spoke configuration? | `bool` | `false` | no |
| <a name="input_org"></a> [org](#input\_org) | Organization details | <pre>object({<br/>    organization_name = string<br/>    organization_unit = string<br/>    environment_type  = string<br/>    environment_name  = string<br/>  })</pre> | n/a | yes |
| <a name="input_request_scripts"></a> [request\_scripts](#input\_request\_scripts) | (optional) Array of request scripts for the Synthetics canaries | <pre>list(object({<br/>    name            = string<br/>    content         = string<br/>    runtime_version = string<br/>    handler         = optional(string, "custom_handler.handler")<br/>  }))</pre> | `[]` | no |
| <a name="input_spoke_def"></a> [spoke\_def](#input\_spoke\_def) | Spoke ID Number, must be a 3 digit number | `string` | `"001"` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | (required) VPC configuration for the Synthetics canaries | <pre>object({<br/>    enabled                     = optional(bool, true)<br/>    vpc_id                      = optional(string, "")<br/>    subnet_ids                  = optional(list(string), [])<br/>    security_group_ids          = optional(list(string), [])<br/>    ipv6_allowed_for_dual_stack = optional(bool)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_artifacts_bucket_arn"></a> [artifacts\_bucket\_arn](#output\_artifacts\_bucket\_arn) | ARN of the S3 artifacts bucket created by this module, or null when an existing bucket is used. |
| <a name="output_artifacts_bucket_name"></a> [artifacts\_bucket\_name](#output\_artifacts\_bucket\_name) | Name of the S3 artifacts bucket created by this module, or null when an existing bucket is used. |
| <a name="output_synthetics_canaries"></a> [synthetics\_canaries](#output\_synthetics\_canaries) | Synthetics canaries created by this module with their group names, map keys, names, ARNs, status, and timeline. |
| <a name="output_synthetics_groups"></a> [synthetics\_groups](#output\_synthetics\_groups) | Synthetics groups created by this module with their map keys, names, and ARNs. |
