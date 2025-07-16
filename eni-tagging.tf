##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_network_interfaces" "synthetic_enis" {
  for_each = {
    for key, group in local.synth_groups : key => group
    if var.vpc.enabled
  }
  filter {
    name   = "interface-type"
    values = ["lambda"]
  }
  filter {
    name   = "group-id"
    values = [aws_security_group.this[each.key].id]
  }
  depends_on = [
    aws_synthetics_canary.this
  ]
}

resource "aws_ec2_tag" "synthetic_enis" {
  for_each = merge(flatten([
    for key, group in local.synth_groups : [
      for eni in data.aws_network_interfaces.synthetic_enis[key].ids : {
        for key_tag, value_tag in merge(
          local.all_tags,
          try(group.tags, {}),
          {
            synthetic_group_key = group.name,
          }
          ) : "${eni}-${key}-${key_tag}" => {
          eni_id = eni
          key    = key_tag
          value  = value_tag
        }
      }
    ]
  ])...)
  resource_id = each.value.eni_id
  key         = each.value.key
  value       = each.value.value
}