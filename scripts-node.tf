##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  zip_files_nodejs = {
    for key, content in local.synthetics : key => {
      bucket_key    = "${local.code_package_prefix}/${key}.zip"
      zip_file_path = "${path.module}/scripts/${key}.zip"
    }
    if content.is_nodejs
  }
  nodejs_synthetics_url = {
    for key, synth in local.synthetics : key => synth
    if synth.is_nodejs && !synth.script_configuration.is_custom
  }
  nodejs_synthetics_custom = {
    for key, synth in local.synthetics : key => synth
    if synth.is_nodejs && synth.script_configuration.is_custom
  }
  nodejs_staging_directory = "/tmp/cloudopsworks-synthetics-nodejs-${random_id.nodejs_staging.hex}"
  # Stage dependencies at apply time; no generated files are needed during plan.
  # Copy directory contents so Linux and macOS produce the same ZIP layout.
  stage_nodejs_command = "npm install --prefix ${local.nodejs_staging_directory}/nodejs --no-save --no-package-lock --omit=dev --cpu=x64 --os=linux js-yaml@4.1.0 @aws-sdk/client-ssm@3.1130.0 && cp -rf ./nodejs/. ${local.nodejs_staging_directory}/nodejs/ && chmod -R u+w ${local.nodejs_staging_directory}/nodejs"
}

resource "random_id" "nodejs_staging" {
  byte_length = 8
  keepers = {
    apply_timestamp = timestamp()
  }
}

resource "terraform_data" "stage_nodejs" {
  triggers_replace = {
    staging_directory = local.nodejs_staging_directory
  }
  provisioner "local-exec" {
    command     = "rm -rf ${local.nodejs_staging_directory} && mkdir -p ${local.nodejs_staging_directory} && ${local.stage_nodejs_command}"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "staging_directory='${try(self.triggers_replace.staging_directory, "")}' && test -z \"$staging_directory\" || rm -rf \"$staging_directory\""
  }
}

# Always recreate the ZIP on the apply runner, even when source inputs are unchanged.
resource "terraform_data" "archive_url_nodejs" {
  for_each         = local.nodejs_synthetics_url
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command     = <<-EOT
      set -eu
      mkdir -p "$(dirname "$ZIP_FILE")"
      rm -f "$ZIP_FILE"
      zip -q -r "$ZIP_FILE" .
    EOT
    working_dir = local.nodejs_staging_directory
    environment = {
      ZIP_FILE = abspath(local.zip_files_nodejs[each.key].zip_file_path)
    }
  }
  depends_on = [terraform_data.stage_nodejs]
}

resource "aws_s3_object" "script_url_nodejs" {
  for_each    = local.nodejs_synthetics_url
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files_nodejs[each.key].bucket_key
  source      = local.zip_files_nodejs[each.key].zip_file_path
  source_hash = terraform_data.archive_url_nodejs[each.key].id
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    terraform_data.archive_url_nodejs
  ]
}

resource "terraform_data" "script_custom_node" {
  for_each         = local.nodejs_synthetics_custom
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
      SCRIPT_PATH    = "nodejs/node_modules/${split(".", each.value.resolved_handler)[0]}.js"
      ZIP_FILE       = abspath(local.zip_files_nodejs[each.key].zip_file_path)
    }
  }
}
