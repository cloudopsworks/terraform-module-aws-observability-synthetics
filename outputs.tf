##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "artifacts_bucket_name" {
  value = var.create_artifacts_bucket ? module.synthetics_artifacts.s3_bucket_id : null
}

output "artifacts_bucket_arn" {
  value = var.create_artifacts_bucket ? module.synthetics_artifacts.s3_bucket_arn : null
}

output "syntetics_groups" {
  value = [
    for key, group in aws_synthetics_group.this : {
      key  = key
      name = group.name
      arn  = group.arn
    }
  ]
}

output "synthetics_canaries" {
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