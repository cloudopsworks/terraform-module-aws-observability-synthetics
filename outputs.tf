##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "artifacts_bucket_name" {
  description = "Name of the S3 artifacts bucket created by this module, or null when an existing bucket is used."
  value       = var.create_artifacts_bucket ? module.synthetics_artifacts.s3_bucket_id : null
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 artifacts bucket created by this module, or null when an existing bucket is used."
  value       = var.create_artifacts_bucket ? module.synthetics_artifacts.s3_bucket_arn : null
}

output "synthetics_groups" {
  description = "Synthetics groups created by this module with their map keys, names, and ARNs."
  value = [
    for key, group in aws_synthetics_group.this : {
      key  = key
      name = group.name
      arn  = group.arn
    }
  ]
}

output "synthetics_canaries" {
  description = "Synthetics canaries created by this module with their group names, map keys, names, ARNs, status, and timeline."
  value = [
    for key, canary in aws_synthetics_canary.this : {
      group_name = aws_synthetics_group_association.this[key].group_name
      key        = key
      name       = canary.name
      arn        = canary.arn
      status     = canary.status
      timeline   = canary.timeline
    }
  ]
}
