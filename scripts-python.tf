##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  canary_requests_content = {
    for key, synthetic in local.synthetics : key => yamlencode({
      requests = synthetic.canary.requests
    })
    if !synthetic.script_configuration.is_custom
  }
  zip_files_python = {
    for key, content in local.synthetics : key => {
      bucket_key    = "${local.code_package_prefix}/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
    }
    if content.is_python
  }
  python_synthetics_url = {
    for key, synth in local.synthetics : key => synth
    if synth.is_python && !synth.script_configuration.is_custom
  }
  python_synthetics_custom = {
    for key, synth in local.synthetics : key => synth
    if synth.is_python && synth.script_configuration.is_custom
  }
  python_staging_directory = "/tmp/cloudopsworks-synthetics-python-${random_id.python_staging.hex}"
  # Stage dependencies at apply time; no generated files are needed during plan.
  # Copy directory contents so Linux and macOS produce the same ZIP layout.
  stage_python_command = "python3 -m pip install -r requirements.txt --target ${local.python_staging_directory}/python --platform manylinux_2_17_x86_64 --python-version 3.11 --implementation cp --only-binary=:all: --no-deps --upgrade && cp -rf ./python/. ${local.python_staging_directory}/python/ && chmod -R u+w ${local.python_staging_directory}/python"
}

resource "random_id" "python_staging" {
  byte_length = 8
  keepers = {
    apply_timestamp = timestamp()
  }
}

resource "terraform_data" "stage_python" {
  triggers_replace = {
    staging_directory = local.python_staging_directory
  }
  provisioner "local-exec" {
    command     = "rm -rf ${local.python_staging_directory} && mkdir -p ${local.python_staging_directory} && ${local.stage_python_command}"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "staging_directory='${try(self.triggers_replace.staging_directory, "")}' && test -z \"$staging_directory\" || rm -rf \"$staging_directory\""
  }
}

# Always recreate the ZIP on the apply runner, even when source inputs are unchanged.
resource "terraform_data" "archive_url_python" {
  for_each         = local.python_synthetics_url
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command     = <<-EOT
      set -eu
      mkdir -p "$(dirname "$ZIP_FILE")"
      rm -f "$ZIP_FILE"
      zip -q -r "$ZIP_FILE" .
    EOT
    working_dir = local.python_staging_directory
    environment = {
      ZIP_FILE = abspath(local.zip_files_python[each.key].zip_file_path)
    }
  }
  depends_on = [terraform_data.stage_python]
}

resource "aws_s3_object" "script_url_python" {
  for_each    = local.python_synthetics_url
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files_python[each.key].bucket_key
  source      = local.zip_files_python[each.key].zip_file_path
  source_hash = terraform_data.archive_url_python[each.key].id
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    terraform_data.archive_url_python
  ]
}

resource "terraform_data" "script_custom_python" {
  for_each         = local.python_synthetics_custom
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      staging_directory=$(mktemp -d)
      trap 'rm -rf "$staging_directory"' EXIT
      mkdir -p "$staging_directory/$(dirname "$SCRIPT_PATH")"
      printf '%s' "$SCRIPT_CONTENT" > "$staging_directory/$SCRIPT_PATH"
      mkdir -p "$(dirname "$ZIP_FILE")"
      rm -f "$ZIP_FILE"
      cd "$staging_directory"
      zip -q -r "$ZIP_FILE" .
    EOT
    environment = {
      SCRIPT_CONTENT = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
      SCRIPT_PATH    = "python/${split(".", each.value.resolved_handler)[0]}.py"
      ZIP_FILE       = abspath(local.zip_files_python[each.key].zip_file_path)
    }
  }
}

# Generic for both Node.js and Python custom scripts
resource "aws_s3_object" "script_custom" {
  for_each    = merge(local.python_synthetics_custom, local.nodejs_synthetics_custom)
  bucket      = local.s3_location_bucket_name
  key         = try(local.zip_files_nodejs[each.key].bucket_key, local.zip_files_python[each.key].bucket_key)
  source      = try(local.zip_files_nodejs[each.key].zip_file_path, local.zip_files_python[each.key].zip_file_path)
  source_hash = try(terraform_data.script_custom_node[each.key].id, terraform_data.script_custom_python[each.key].id)
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    terraform_data.script_custom_node,
    terraform_data.script_custom_python,
  ]
}
