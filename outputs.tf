
locals {

  # Launchpad config object which could be output to yaml.
  # @NOTE we use an object so that it can be interpreted in parts, and read as
  #    using `terraform output -json`
  launchpad_1_3 = yamldecode(templatefile("${path.module}/templates/mke_cluster.1_3.tpl",
    {
      cluster_name = local.cluster_name
      key_path     = local.key_path

      hosts = local.hosts

      mcr_version           = var.mcr_version
      mcr_channel           = var.mcr_channel
      mcr_repoURL           = var.mcr_repo_url
      mcr_installURLLinux   = var.mcr_install_url_linux
      mcr_installURLWindows = var.mcr_install_url_windows

      mke_version        = var.mke_version
      mke_image_repo     = var.mke_image_repo
      mke_admin_username = var.admin_username
      mke_admin_password = var.admin_password
      mke_san            = module.elb_mke.lb_dns_name
      mke_installFlags   = local.mke_install_flags
      mke_upgradeFlags   = []

      msr_version        = var.msr_version
      msr_image_repo     = var.msr_image_repo
      msr_count          = local.msr_count
      msr_installFlags   = local.msr_install_flags
      msr_replica_config = var.msr_replica_config

      cluster_prune = false

      msr_nfs_storage_url = try(local.efs.dns_name, "")
    }
  ))

  # toolbox config object which could be output to yaml.
  # @NOTE we use an object so that it can be interpreted in parts, and read as
  #    using `terraform output -json`
  nodes = yamldecode(templatefile("${path.module}/templates/nodes_yaml.tpl",
    {
      key_path = local.key_path
      hosts    = local.hosts
    }
  ))

  mke4_upgrade = templatefile("${path.module}/templates/mke4_upgrade.tpl",
    {
      key_path = abspath(local.key_path)
      hosts    = local.hosts
    }
  )

  mke4_install = templatefile("${path.module}/templates/mke4_install.tpl",
    {
      key_path                    = abspath(local.key_path)
      hosts                       = local.hosts
      lb                          = module.elb_mke4.lb_dns_name
      ingress_controller_replicas = var.ingress_controller_replicas
    }
  )

  blueprint = templatefile("${path.module}/templates/bop_blueprint.tpl",
    {
      key_path = local.key_path
      hosts    = local.hosts
      managers = local.managers.instances
      mke_san  = module.elb_mke.lb_dns_name
    }
  )

  k0sctl = templatefile("${path.module}/templates/k0sctl.tpl",
    {
      key_path = local.key_path
      hosts    = local.hosts
      managers = local.managers.instances
      mke_san  = module.elb_mke.lb_dns_name
    }
  )

  # Ansible config object which could be output to yaml.
  # @NOTE we use an object so that it can be interpreted in parts, and read as
  #    using `terraform output -json`
  ansible_inventory = templatefile("${path.module}/templates/ansible_inventory.tpl",
    {
      # user      = local.ami_obj.user,
      key_file      = local.key_path,
      win_passwd    = var.win_admin_password,
      mgr_hosts     = local.managers.instances,
      mgr_user      = local.managers.user,
      mgr_idxs      = range(var.manager_count),
      wkr_hosts     = local.workers.instances,
      wkr_user      = local.workers.user,
      wkr_idxs      = range(local.worker_count),
      msr_hosts     = local.msrs.instances,
      msr_user      = local.msrs.user,
      msr_idxs      = range(local.msr_count),
      win_wkr_hosts = local.windows_workers.instances,
      win_wkr_idxs  = range(var.windows_worker_count),
      linux_user    = local.managers.user
    }
  )
}

# Various outputs for different format

output "hosts" {
  value = local.hosts
}

output "launchpad" {
  value = local.launchpad_1_3
}

output "mke_cluster" {
  value = yamlencode(local.launchpad_1_3)
}

output "nodes" {
  value = local.nodes
}

output "nodes_yaml" {
  value = yamlencode(local.nodes)
}

output "mke4_install" {
  value = local.mke4_install
}

output "mke4_upgrade" {
  value = local.mke4_upgrade
}

output "blueprint" {
  value = local.blueprint
}

output "k0sctl" {
  value = local.k0sctl
}

output "cluster_name" {
  value = local.cluster_name
}

output "mke_lb" {
  value = "https://${module.elb_mke.lb_dns_name}"
}

output "mke4_lb" {
  value = "https://${module.elb_mke4.lb_dns_name}"
}

# Use this output is you are trying to build your own launchpad yaml and need
# the value for "--san={}
output "mke_san" {
  value = module.elb_mke.lb_dns_name
}

output "msr_lb" {
  # If no MSR replicas, then no LB should exist
  value = try("https://${local.elb_msr}", "")
}

output "nfs_server" {
  value = try(local.efs.dns_name, null)
}

output "ansible_inventory" {
  value = local.ansible_inventory
}

output "aws_region" {
  value = var.aws_region
}

output "mkectl_upgrade_command" {
  value = "mkectl upgrade --hosts-path mke4_upgrade.yaml --admin-username ${var.admin_username} --admin-password ${var.admin_password} -l debug --config-out mke4.yaml --external-address \"${module.elb_mke.lb_dns_name}\""
}

# Write configs to YAML files

resource "local_file" "launchpad_yaml" {
  content  = yamlencode(local.launchpad_1_3)
  filename = "launchpad.yaml"
}

resource "local_file" "nodes_yaml" {
  content  = yamlencode(local.nodes)
  filename = "nodes.yaml"
}

# Create Ansible inventory file
resource "local_file" "ansible_inventory" {
  content  = local.ansible_inventory
  filename = "hosts.ini"
}

resource "local_file" "mke4_install" {
  content  = local.mke4_install
  filename = "mke4_install.yaml"
}

resource "local_file" "mke4_upgrade" {
  content  = local.mke4_upgrade
  filename = "mke4_upgrade.yaml"
}

resource "local_file" "blueprint" {
  content  = local.blueprint
  filename = "blueprint.yaml"
}

resource "local_file" "k0sctl" {
  content  = local.k0sctl
  filename = "k0sctl.yaml"
}
