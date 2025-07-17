##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  # compute hash from ${path.module}/sources will generate on changes from updates from this module
  hash_sources = upper(
    sha256(
      join("", [
        filesha256("${path.module}/sources/standard/requirements.txt"),
        filesha256("${path.module}/sources/standard/nodejs/node_modules/canary_handler.js"),
        filesha256("${path.module}/sources/standard/python/canary_handler.py"),
      ])
    )
  )
  canary_requests_content = {
    for key, synthetic in local.synthetics : key => yamlencode({
      requests = synthetic.canary.requests
    })
    if synthetic.is_url
  }
  hash_requests_content = {
    for key, content in local.canary_requests_content : key => upper(sha256(content))
  }
  zip_files_python = {
    for key, content in local.synthetics : key => {
      file_path     = "${path.module}/sources/standard/${key}/python/"
      file_name     = "${key}_config.yaml"
      bucket_key    = "upload/scripts/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
    }
    if content.is_python
  }
  python_synthetics_all = {
    for key, synth in local.synthetics : key => synth
    if synth.is_python
  }
  python_synthetics_url = {
    for key, synth in local.synthetics : key => synth
    if synth.is_python && synth.is_url
  }
  python_synthetics_custom = {
    for key, synth in local.synthetics : key => synth
    if synth.is_python && synth.is_script
  }
}

resource "local_file" "script_config_python" {
  for_each        = local.python_synthetics_all
  content         = local.canary_requests_content[each.key]
  filename        = format("%s%s", local.zip_files_python[each.key].file_path, local.zip_files_python[each.key].file_name)
  file_permission = "0644"
  depends_on = [
    null_resource.stage_python
  ]
  lifecycle {
    replace_triggered_by = [
      null_resource.stage_python[each.key],
    ]
  }
}

resource "null_resource" "stage_python" {
  triggers = {
    always = timestamp()
  }
  provisioner "local-exec" {
    command     = "python3 -m pip install -r requirements.txt --target ./stage/python --platform manylinux_2_17_x86_64 --python-version 3.11 --no-deps --upgrade"
    working_dir = "${path.module}/sources/standard/"
  }
  provisioner "local-exec" {
    command     = "cp -r ./python/ ./stage/python/"
    working_dir = "${path.module}/sources/standard"
  }
}

resource "null_resource" "this_python" {
  for_each = local.python_synthetics_url
  triggers = {
    hash_requests_content = local.hash_requests_content[each.key]
  }
  provisioner "local-exec" {
    command     = "cp -r ./stage/python ./${each.key}/"
    working_dir = "${path.module}/sources/standard"
  }
  depends_on = [
    null_resource.stage_python,
    local_file.script_config_python
  ]
}

resource "null_resource" "archive_url_python" {
  for_each = local.python_synthetics_url
  triggers = {
    script_config = local_file.script_config_python[each.key].content_sha256
  }
  provisioner "local-exec" {
    command     = "zip -r ${local.zip_files_python[each.key].zip_file_path} ."
    working_dir = "${path.module}/sources/standard/${each.key}/"
  }
  depends_on = [
    null_resource.this_python,
    local_file.script_config_python
  ]
}

# resource "archive_file" "script_url_python" {
#   for_each    = local.python_synthetics_url
#   output_path = local.zip_files_python[each.key].zip_file_path
#   type        = "zip"
#   source_dir  = "${path.module}/sources/standard/${each.key}/"
#   excludes = [
#     "example*.yaml",
#     "requirements.txt",
#     "nodejs/**/*",
#   ]
#   depends_on = [
#     null_resource.stage_python,
#     null_resource.this_python,
#     local_file.script_config_python
#   ]
#   lifecycle {
#     replace_triggered_by = [
#       local_file.script_config_python[each.key].content_sha256,
#     ]
#   }
# }

resource "aws_s3_object" "script_url_python" {
  for_each    = local.python_synthetics_url
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files_python[each.key].bucket_key
  source      = local.zip_files_python[each.key].zip_file_path
  source_hash = local.hash_requests_content[each.key]
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    null_resource.archive_url_python,
    local_file.script_config_python
  ]
}

resource "local_file" "script_custom_python" {
  for_each        = local.python_synthetics_custom
  content         = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
  filename        = "${path.module}/sources/custom/${each.key}/python/custom_handler.py"
  file_permission = "0644"
}

resource "archive_file" "script_custom_python" {
  for_each    = local.python_synthetics_custom
  output_path = local.zip_files_python[each.key].zip_file_path
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
      local_file.script_custom_python[each.key].content_sha256,
    ]
  }
}

# Generic for both Node.js and Python custom scripts
resource "aws_s3_object" "script_custom" {
  for_each    = merge(local.python_synthetics_custom, local.nodejs_synthetics_custom)
  bucket      = local.s3_location_bucket_name
  key         = try(local.zip_files_nodejs[each.key].bucket_key, local.zip_files_python[each.key].bucket_key)
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
