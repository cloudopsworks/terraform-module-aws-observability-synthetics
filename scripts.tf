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
  hash_sources = upper(sha256(join("", [for file_to_hash in fileset(".", "${path.module}/sources/**") : filesha256(file_to_hash)])))
  canary_content = {
    for key, synthetic in local.synthetics : key => yamlencode({
      requests = synthetic.canary.requests
    })
  }
  hash_content = {
    for key, content in local.canary_content : key => upper(sha256(content))
  }
  zip_files = {
    for key, content in local.canary_content : key => {
      file_path     = "${path.module}/sources/"
      file_name     = "${key}_config.yaml"
      bucket_key    = "upload/scripts/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
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
  provisioner "local-exec" {
    command = "pip install -r requirements.txt --target . --platform manylinux_2_17_x86_64 --python-version 3.11 --no-deps --upgrade"
    working_dir = local.zip_files[each.key].file_path
  }
}

resource "archive_file" "script" {
  for_each    = local.synthetics
  output_path = local.zip_files[each.key].zip_file_path
  type        = "zip"
  source_dir  = local.zip_files[each.key].file_path
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

resource "aws_s3_object" "script" {
  for_each    = local.synthetics
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files[each.key].bucket_key
  source      = archive_file.script[each.key].output_path
  source_hash = sha256(format("%s-%s", local.hash_content[each.key], local.hash_sources))
  # tags = merge(
  #   local.all_tags,
  #   try(each.value.group.tags, {}),
  #   try(each.value.canary.tags, {}),
  #   {
  #     synthetic_group_key  = each.value.group.name
  #     synthetic_canary_key = each.value.canary.name
  #   }
  # )
}
