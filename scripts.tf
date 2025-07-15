##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

resource "local_file" "script_config" {
  for_each = local.syntetics
  content = yamlencode({
    requests = each.value.canary.requests
  })
  filename        = "${path.module}/sources/${each.key}_config.yaml"
  file_permission = "0644"
}

resource "archive_file" "script" {
  for_each    = local.syntetics
  output_path = "${path.module}/scripts/${each.key}.zip"
  type        = "zip"
  source_dir  = "${path.module}/sources"
  excludes = [
    "${path.module}/sources/example*.yaml"
  ]
  depends_on = [
    local_file.script_config
  ]
}
