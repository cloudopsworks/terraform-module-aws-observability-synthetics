##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  zip_files_nodejs = {
    for key, content in local.synthetics : key => {
      file_path     = "${path.module}/sources/standard/${key}/nodejs/"
      file_name     = "${key}_config.yaml"
      bucket_key    = "upload/scripts/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
    }
    if content.is_nodejs
  }
  nodejs_synthetics_all = {
    for key, synth in local.synthetics : key => synth
    if synth.is_nodejs
  }
  nodejs_synthetics_url = {
    for key, synth in local.synthetics : key => synth
    if synth.is_nodejs && synth.is_url
  }
  nodejs_synthetics_custom = {
    for key, synth in local.synthetics : key => synth
    if synth.is_nodejs && synth.is_script
  }
}

resource "local_file" "script_config_nodejs" {
  for_each        = local.nodejs_synthetics_all
  content         = local.canary_requests_content[each.key]
  filename        = format("%s%s", local.zip_files_nodejs[each.key].file_path, local.zip_files_nodejs[each.key].file_name)
  file_permission = "0644"
  depends_on = [
    null_resource.stage_nodejs
  ]
}

resource "null_resource" "stage_nodejs" {
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command     = "npm install --prefix ./stage/nodejs --no-save --no-package-json --no-package-lock --omit=dev --target_arch=x64 --target_platform=linux js-yaml"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    command     = "cp -r ./nodejs/ ./stage/nodejs/node_modules/"
    working_dir = "${path.module}/sources/standard"
  }
}

resource "null_resource" "this_nodejs" {
  for_each = local.nodejs_synthetics_url
  triggers = {
    hash_requests_content = local.hash_requests_content[each.key]
  }
  provisioner "local-exec" {
    command     = "cp -r ./stage/nodejs ./${each.key}/nodejs"
    working_dir = "${path.module}/sources/standard"
  }
  depends_on = [
    null_resource.stage_nodejs,
    local_file.script_config_nodejs
  ]
}

resource "archive_file" "script_url_nodejs" {
  for_each    = local.nodejs_synthetics_url
  output_path = local.zip_files_nodejs[each.key].zip_file_path
  type        = "zip"
  source_dir  = "${path.module}/sources/standard/${each.key}"
  excludes = [
    "**/example*.yaml",
    "**/requirements.txt",
  ]
  depends_on = [
    null_resource.this_nodejs,
    local_file.script_config_nodejs
  ]
  lifecycle {
    replace_triggered_by = [
      local_file.script_config_nodejs[each.key].content_sha256,
    ]
  }
}

resource "aws_s3_object" "script_url_nodejs" {
  for_each    = local.nodejs_synthetics_url
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files_nodejs[each.key].bucket_key
  source      = archive_file.script_url_nodejs[each.key].output_path
  source_hash = archive_file.script_url_nodejs[each.key].output_sha256
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
}

resource "local_file" "script_custom_node" {
  for_each        = local.nodejs_synthetics_custom
  content         = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
  filename        = "${path.module}/sources/custom/${each.key}/nodejs/node_modules/custom_handler.js"
  file_permission = "0644"
}

resource "archive_file" "script_custom_node" {
  for_each    = local.nodejs_synthetics_custom
  output_path = local.zip_files_nodejs[each.key].zip_file_path
  type        = "zip"
  source_dir  = "${path.module}/sources/custom/${each.key}/"
  excludes = [
    "**/example*.yaml",
    "**/requirements.txt",
  ]
  depends_on = [
    local_file.script_custom_node,
  ]
  lifecycle {
    replace_triggered_by = [
      local_file.script_custom_node[each.key].content_sha256,
    ]
  }
}

