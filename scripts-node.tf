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
  nodejs_scripts_sha       = sha256(join("", [for item in fileset("${path.module}", "sources/standard/nodejs/**/*.js") : filesha256(item)]))
  nodejs_dependencies_sha  = sha256("js-yaml@4.1.0,@aws-sdk/client-ssm@3.1130.0")
  # Runtime version is part of the packaged code identity: the AWS Synthetics API
  # rejects UpdateCanary when the runtime changes without a Code payload, and the
  # provider only sends Code when s3_bucket/s3_key/s3_version/handler change.
  nodejs_runtimes_sha = sha256(join(",", [for key in sort(keys(local.nodejs_synthetics_url)) : local.nodejs_synthetics_url[key].resolved_runtime_version]))
  # Staging is a filesystem side effect. Each apply uses a unique directory under
  # /tmp so module sources and concurrent module runs never share package contents.
  # --cpu/--os are the npm configs that actually cross-target the Lambda x86_64 Linux
  # runtime. The former --target_arch/--target_platform/--no-package-json were never
  # npm configs at all: npm 11 ignores them with a warning and npm 12 rejects them
  # outright with EUNKNOWNCONFIG.
  # Terragrunt writes its module cache read-only (0444), so a plain cp propagates that
  # mode to the staged copy and the next cp cannot open the destination. -f removes the
  # destination first, and chmod restores write permission so anything copied out of
  # the temporary staging directory later is writable too.
  stage_nodejs_command = "npm install --prefix ${local.nodejs_staging_directory}/nodejs --no-save --no-package-lock --omit=dev --cpu=x64 --os=linux js-yaml@4.1.0 @aws-sdk/client-ssm@3.1130.0 && cp -rf ./nodejs/ ${local.nodejs_staging_directory}/nodejs/ && chmod -R u+w ${local.nodejs_staging_directory}/nodejs"
}

resource "random_id" "nodejs_staging" {
  byte_length = 8
  keepers = {
    apply_timestamp = timestamp()
  }
}

resource "null_resource" "stage_nodejs" {
  triggers = {
    scripts_sha       = local.nodejs_scripts_sha
    dependencies_sha  = local.nodejs_dependencies_sha
    runtimes_sha      = local.nodejs_runtimes_sha
    staging_directory = local.nodejs_staging_directory
  }
  provisioner "local-exec" {
    command     = "rm -rf ${local.nodejs_staging_directory} && mkdir -p ${local.nodejs_staging_directory} && ${local.stage_nodejs_command}"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.staging_directory}"
  }
}

resource "null_resource" "archive_url_nodejs" {
  for_each = local.nodejs_synthetics_url
  triggers = {
    scripts_sha      = local.nodejs_scripts_sha
    dependencies_sha = local.nodejs_dependencies_sha
    runtime_version  = each.value.resolved_runtime_version
    force_rebuild    = local.group_force_rebuild[each.value.group.name]
  }
  provisioner "local-exec" {
    command     = "cp -rf ${local.nodejs_staging_directory}/nodejs ./${each.key}/"
    working_dir = "${path.module}/sources/standard"
  }
  provisioner "local-exec" {
    command     = "zip -q -r /tmp/${each.key}.zip ."
    working_dir = "${path.module}/sources/standard/${each.key}/"
  }
  provisioner "local-exec" {
    command = "mv /tmp/${each.key}.zip ${local.zip_files_nodejs[each.key].zip_file_path}"
  }
  depends_on = [
    null_resource.stage_nodejs,
  ]
}


resource "aws_s3_object" "script_url_nodejs" {
  for_each    = local.nodejs_synthetics_url
  bucket      = local.s3_location_bucket_name
  key         = local.zip_files_nodejs[each.key].bucket_key
  source      = local.zip_files_nodejs[each.key].zip_file_path
  source_hash = "${local.nodejs_scripts_sha}-${local.nodejs_dependencies_sha}-${each.value.resolved_runtime_version}-${local.group_force_rebuild[each.value.group.name]}"
  tags = {
    synthetic_group_key  = each.value.group.name
    synthetic_canary_key = each.value.canary.name
  }
  depends_on = [
    null_resource.archive_url_nodejs
  ]
}

resource "local_file" "script_custom_node" {
  for_each        = local.nodejs_synthetics_custom
  content         = try(local.request_scripts_map[each.value.canary.request_script_ref].content, each.value.canary.request_script)
  filename        = "${path.module}/sources/custom/${each.key}/nodejs/node_modules/${split(".", each.value.resolved_handler)[0]}.js"
  file_permission = "0644"
}

resource "terraform_data" "script_custom_node" {
  for_each = local.nodejs_synthetics_custom
  input = {
    zip_file = local.zip_files_nodejs[each.key].zip_file_path
    sha256   = "${local_file.script_custom_node[each.key].content_sha256}-${each.value.resolved_runtime_version}-${local.group_force_rebuild[each.value.group.name]}"
  }
  triggers_replace = [
    local_file.script_custom_node[each.key].content_sha256,
    each.value.resolved_runtime_version,
    local.group_force_rebuild[each.value.group.name],
  ]
  provisioner "local-exec" {
    command     = "zip -r /tmp/${each.key}-custom.zip ."
    working_dir = "${path.module}/sources/custom/${each.key}/"
  }
  provisioner "local-exec" {
    command = "mv /tmp/${each.key}-custom.zip ${local.zip_files_nodejs[each.key].zip_file_path}"
  }
  depends_on = [
    local_file.script_custom_node,
  ]
}

# resource "archive_file" "script_custom_node" {
#   for_each    = local.nodejs_synthetics_custom
#   output_path = local.zip_files_nodejs[each.key].zip_file_path
#   type        = "zip"
#   source_dir  = "${path.module}/sources/custom/${each.key}/"
#   excludes = [
#     "**/example*.yaml",
#     "**/requirements.txt",
#   ]
#   depends_on = [
#     local_file.script_custom_node,
#   ]
#   lifecycle {
#     replace_triggered_by = [
#       local_file.script_custom_node[each.key].content_sha256,
#     ]
#   }
# }
