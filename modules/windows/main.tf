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
  user_data_windows = templatefile(
    "${path.module}/../templates/user_data_windows.tpl",
    {
      win_admin_password = var.win_admin_password
      enable_fips        = var.enable_fips
    }
  )
}

# Useful for troubleshooting the Windows user-data script - uncomment as needed
# resource "local_file" "user_data_windows_file" {
#   filename = "${path.module}/output/user_data_windows.txt"
#   content  = local.user_data_windows
# }


module "ami" {
  source   = "../ami"
  platform = local.platform
}

locals {
  # node_ids  = var.life_cycle == "spot" ? module.spot.node_ids : module.ondemand.node_ids
  # instances = var.life_cycle == "spot" ? module.spot.instances : module.ondemand.instances
  node_ids  = module.ondemand.node_ids
  instances = module.ondemand.instances
}

# module "spot" {
#   source        = "../spot"
#   globals       = var.globals
#   node_count    = var.life_cycle == "spot" ? var.node_count : 0
#   image_id      = module.ami.image_id
#   instance_type = var.instance_type
#   volume_size   = var.volume_size
#   tags          = local.tags
#   user_data     = base64encode(local.user_data_windows)
# }

module "ondemand" {
  source        = "../ondemand"
  globals       = var.globals
  # node_count    = var.life_cycle == "ondemand" ? var.node_count : 0
  node_count    = var.node_count
  image_id      = module.ami.image_id
  instance_type = var.instance_type
  volume_size   = var.volume_size
  tags          = local.tags
  user_data     = base64encode(local.user_data_windows)
}

resource "null_resource" "cluster" {
  triggers = {
    cluster_instance_ids = join(",", local.node_ids)
  }
  count = length(local.instances)

  provisioner "remote-exec" {
    connection {
      host     = local.instances[count.index].public_ip
      type     = "winrm"
      user     = module.ami.user
      password = var.win_admin_password
      timeout  = "10m"
      https    = "true"
      insecure = "true"
      port     = 5986
    }
    inline = [
      "hostname"
    ]
  }
}
