##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

resource "aws_security_group" "this" {
  for_each = {
    for key, group in local.synth_groups : key => group
    if var.vpc.enabled && try(group.vpc.enabled, true)
  }
  name        = format("%s-%s-sg", each.key, local.system_name)
  description = "Security group for ${each.key} Synthetics canary"
  vpc_id      = var.vpc.vpc_id
  egress { # Allow all outbound traffic
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.all_tags, try(each.value.tags, {}))
  depends_on = [
    aws_iam_role.this
  ]
  lifecycle {
    create_before_destroy = true
  }
}