locals {
  ymlfile = "${var.dir}/${var.file_name}"
  configs = yamldecode(file(local.ymlfile))
  regs = local.configs.apps
}