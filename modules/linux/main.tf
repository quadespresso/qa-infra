###
# All linux platforms
###

locals {
  os = "linux"
  role_tag = {
    "Name" = "${var.globals.cluster_name}-${var.role}"
    "Role" = var.role
  }
  tags = merge(
    var.globals.tags,
    local.role_tag
  )
  tags_nokube = merge(
    var.globals.tags_nokube,
    local.role_tag
  )
  scripts_dir       = "${path.module}/../scripts"
  base_linux_script = file("${local.scripts_dir}/user_data_linux.sh")

  platform_script = fileexists(
    "${local.scripts_dir}/user_data_${var.globals.platform}.sh"
    ) ? (
    file(
      "${local.scripts_dir}/user_data_${var.globals.platform}.sh"
    )
    ) : (
    file(
      "${local.scripts_dir}/user_data_default.sh"
    )
  )
  role_platform    = var.globals.role_platform
  default_platform = var.globals.default_platform
  platform = coalesce(
    local.role_platform[var.role],
    local.default_platform[local.os]
  )
  instances = module.spot.instances
  distro    = split("_", local.platform)[0]
}

# get image ID from platform name
module "ami" {
  source   = "../ami"
  platform = local.platform
}

data "template_file" "distro_script" {
  template = (
    file(
      "${local.scripts_dir}/user_data_${local.distro}.sh"
    )
  )
  vars = {
    # future use
  }
}

data "cloudinit_config" "linux" {
  part {
    content_type = "text/x-shellscript"
    content      = local.base_linux_script
    filename     = "baselinux.sh"
  }
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.distro_script.rendered
    filename     = "distro.sh"
  }
  part {
    content_type = "text/x-shellscript"
    content      = local.platform_script
    filename     = "platform.sh"
  }
}

module "spot" {
  source        = "../spot"
  globals       = var.globals
  node_count    = var.node_count
  image_id      = module.ami.image_id
  instance_type = var.instance_type
  volume_size   = var.volume_size
  tags          = local.tags
  user_data     = data.cloudinit_config.linux.rendered
}

# Verify node Ready state post-cloud-init
# @NOTE Remote ssh into each node and verify that cloud-init
#    has completed, prior to concluding terraform run.
#    Safeguards against launchpad starting prior to user-init
#    completing.
resource "null_resource" "cluster" {
  triggers = {
    cluster_instance_ids = join(",", module.spot.node_ids)
  }
  count = length(local.instances)

  connection {
    type        = "ssh"
    host        = local.instances[count.index].public_ip
    user        = module.ami.user
    private_key = file(var.globals.key_path)
    agent       = false
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait"
    ]
  }
}
