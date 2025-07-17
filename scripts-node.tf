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
      file_path     = "${path.module}/sources/standard/nodejs/"
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
}

resource "null_resource" "this_nodejs" {
  triggers = {
    hash_sources = local.hash_sources
  }
  provisioner "local-exec" {
    command     = "npm install --prefix ./nodejs-temp --no-save --no-package-json --no-package-lock --omit=dev --target_arch=x64 --target_platform=linux js-yaml"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    command     = "cp -r ./nodejs-temp/node_modules/ ./nodejs/node_modules/"
    working_dir = "${path.module}/sources/standard"
  }
}

resource "archive_file" "script_url_nodejs" {
  for_each    = local.nodejs_synthetics_url
  output_path = local.zip_files_nodejs[each.key].zip_file_path
  type        = "zip"
  source_dir  = "${path.module}/sources/standard"
  excludes = [
    "**/example*.yaml",
    "**/requirements.txt",
    "**/python/**/*",
    "**/nodejs-tmp/**/*",
  ]
  depends_on = [
    local_file.script_config_nodejs
  ]
  lifecycle {
    replace_triggered_by = [
      null_resource.this_nodejs,
      local_file.script_config_nodejs[each.key].id,
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
    "**/python/**/*",
    "**/nodejs-tmp/**/*",
  ]
  depends_on = [
    local_file.script_custom_node,
  ]
  lifecycle {
    replace_triggered_by = [
      null_resource.this_nodejs,
      local_file.script_custom_node[each.key].id,
    ]
  }
}

