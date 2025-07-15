##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  # compute has from ${path.module}/sources
  hash_sources = base64sha256(join("", [for file_to_hash in fileset(".", "${path.module}/sources/**") : filesha256(file_to_hash)]))
  canary_content = {
    for key, synthetic in local.synthetics : key => yamlencode({
      requests = synthetic.canary.requests
    })
  }
  hash_content = {
    for key, content in local.canary_content : key => base64sha256(content)
  }
  zip_files = {
    for key, content in local.canary_content : key => {
      file_path = "${path.module}/sources/"
      file_name = "${key}_${substr(local.hash_sources, 0, 6)}${substr(local.hash_content[key], 0, 6)}_config.yaml"
    }
  }
}

resource "local_file" "script_config" {
  for_each        = local.synthetics
  content         = local.canary_content[each.key]
  filename        = format("%s%s", local.zip_files[each.key].file_path, local.zip_files[each.key].file_name)
  file_permission = "0644"
}

resource "null_resource" "this" {
  triggers = {
    hash_sources = local.hash_sources
  }
}

resource "archive_file" "script" {
  for_each    = local.synthetics
  output_path = "${path.module}/scripts/${each.key}.zip"
  type        = "zip"
  source_dir  = "${path.module}/sources"
  excludes = [
    "example*.yaml"
  ]
  depends_on = [
    local_file.script_config
  ]
  lifecycle {
    replace_triggered_by = [
      null_resource.this,
      local_file.script_config[each.key].id,
    ]
  }
}
