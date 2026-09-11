##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

resource "aws_ssm_parameter" "canary_config" {
  for_each = local.standard_synthetics

  name        = "${each.value.canary_final_name}-config"
  description = "Runtime request configuration for Synthetics canary ${each.value.canary_final_name}."
  type        = "SecureString"
  value       = local.canary_requests_content[each.key]
  tier        = "Standard"

  tags = merge(
    local.all_tags,
    try(each.value.group.tags, {}),
    try(each.value.canary.tags, {}),
    {
      synthetic-group-key  = each.value.group.name
      synthetic-canary-key = each.value.canary.name
    }
  )
}
