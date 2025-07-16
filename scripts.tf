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
    if upper(try(synthetic.canary.requests_type, "URL")) == "URL"
  }
  hash_content = {
    for key, content in local.canary_content : key => upper(sha256(content))
  }
  zip_files = {
    for key, content in local.synthetics : key => {
      file_path     = "${path.module}/sources/standard/python/"
      file_name     = "${key}_config.yaml"
      bucket_key    = "upload/scripts/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
    }
  }
}

resource "local_file" "script_config" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "URL"
  }
  content         = local.canary_content[each.key]
  filename        = format("%s%s", local.zip_files[each.key].file_path, local.zip_files[each.key].file_name)
  file_permission = "0644"
}

resource "null_resource" "this" {
  triggers = {
    hash_sources = local.hash_sources
  }
  provisioner "local-exec" {
    command     = "python3 -m pip install -r requirements.txt --target ./python --platform manylinux_2_17_x86_64 --python-version 3.11 --no-deps --upgrade"
    working_dir = "${path.module}/sources/standard"
  }
}

resource "archive_file" "script_url" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "URL"
  }
  output_path = local.zip_files[each.key].zip_file_path
  type        = "zip"
  source_dir  = "${path.module}/sources/standard"
  excludes = [
    "example*.yaml",
    "requirements.txt",
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

resource "aws_s3_object" "script_url" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "URL"
  }
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files[each.key].bucket_key
  source      = archive_file.script_url[each.key].output_path
  source_hash = sha256(format("%s-%s", local.hash_content[each.key], local.hash_sources))
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
}

resource "local_file" "script_custom_node" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "SCRIPT" && strcontains(try(local.request_scripts_map[synth.canary.request_script_ref].runtime_version, synth.canary.runtime_version, local.default_runtime_version), "nodejs")
  }
  content         = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
  filename        = "${path.module}/sources/custom/${each.key}/nodejs/node_modules/custom_handler.js"
  file_permission = "0644"
}

resource "local_file" "script_custom_python" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "SCRIPT" && strcontains(try(local.request_scripts_map[synth.canary.request_script_ref].runtime_version, synth.canary.runtime_version, local.default_runtime_version), "python")
  }
  content         = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
  filename        = "${path.module}/sources/custom/${each.key}/python/custom_handler.py"
  file_permission = "0644"
}

resource "archive_file" "script_custom_node" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "SCRIPT" && strcontains(try(local.request_scripts_map[synth.canary.request_script_ref].runtime_version, synth.canary.runtime_version, local.default_runtime_version), "nodejs")
  }
  output_path = local.zip_files[each.key].zip_file_path
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
      null_resource.this,
      local_file.script_custom_node[each.key].id,
    ]
  }
}

resource "archive_file" "script_custom_python" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "SCRIPT" && strcontains(try(local.request_scripts_map[synth.canary.request_script_ref].runtime_version, synth.canary.runtime_version, local.default_runtime_version), "python")
  }
  output_path = local.zip_files[each.key].zip_file_path
  type        = "zip"
  source_dir  = "${path.module}/sources/custom/${each.key}/"
  excludes = [
    "**/example*.yaml",
    "**/requirements.txt",
  ]
  depends_on = [
    local_file.script_custom_python,
  ]
  lifecycle {
    replace_triggered_by = [
      null_resource.this,
      local_file.script_custom_python[each.key].id,
    ]
  }
}

resource "aws_s3_object" "script_custom" {
  for_each = {
    for key, synth in local.synthetics : key => synth
    if upper(try(synth.canary.requests_type, "URL")) == "SCRIPT"
  }
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files[each.key].bucket_key
  source      = try(archive_file.script_custom_node[each.key].output_path, archive_file.script_custom_python[each.key].output_path)
  source_hash = try(archive_file.script_custom_node[each.key].output_sha256, archive_file.script_custom_python[each.key].output_sha256)
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    archive_file.script_custom_node,
    archive_file.script_custom_python,
  ]
}
