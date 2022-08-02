###
# Windows platforms only
###

locals {
  os = "windows"
  tag_role = {
    "Name"     = "${var.globals.cluster_name}-win-${var.role}"
    "Role"     = var.role
    "platform" = local.platform
  }
  tags = merge(
    var.globals.tags,
    local.tag_role
  )
  tags_nokube = merge(
    var.globals.tags_nokube,
    local.tag_role
  )
  platform = var.globals.default_platform[local.os]
}

module "ami" {
  source   = "../ami"
  platform = local.platform
}

data "template_file" "windows" {
  template = file("${path.module}/../templates/user_data_windows.tpl")
  vars = {
    win_admin_password = var.win_admin_password
  }
}

module "spot" {
  source     = "../spot"
  globals    = var.globals
  node_count = var.node_count
  # image_id      = var.image_id
  image_id      = module.ami.image_id
  instance_type = var.instance_type
  # role          = var.role
  volume_size = var.volume_size
  tags        = local.tags
  user_data   = base64encode(data.template_file.windows.rendered)
}
