##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  created_artifacts_bucket = "synthetics-artifacts-${local.system_name}"
}

module "synthetics_artifacts" {
  source                                = "terraform-aws-modules/s3-bucket/aws"
  version                               = "~> 5.1"
  bucket                                = local.created_artifacts_bucket
  acl                                   = "private"
  block_public_acls                     = true
  block_public_policy                   = true
  ignore_public_acls                    = true
  restrict_public_buckets               = true
  attach_public_policy                  = true
  attach_require_latest_tls_policy      = true
  attach_deny_insecure_transport_policy = true
  attach_policy                         = true
  policy                                = ""
  control_object_ownership              = true
  object_ownership                      = "ObjectWriter"
  versioning = {
    enabled = true
  }
  tags = local.all_tags
}