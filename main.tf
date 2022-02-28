resource "random_string" "random" {
  length      = 6
  special     = false
  lower       = false
  min_upper   = 2
  min_numeric = 2
}

resource "time_static" "now" {}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source      = "./modules/vpc"
  host_cidr   = var.vpc_cidr
  global_tags = local.global_tags
}

module "efs" {
  source  = "./modules/efs"
  count   = (
      local.msr_count > 0
    ) || (
      local.msr_version_major >= 3
    ) ? 1 : 0
  globals = local.globals
}

module "common" {
  source           = "./modules/common"
  cluster_name     = local.cluster_name
  vpc_id           = module.vpc.id
  ami_obj          = local.ami_obj
  ami_obj_win      = local.ami_obj_win
  key_path         = local.key_path
  open_sg_for_myip = var.open_sg_for_myip
  global_tags      = local.global_tags
}

module "elb_mke" {
  source      = "./modules/elb"
  component   = "mke"
  ports       = [local.controller_port, "6443"]
  machine_ids = module.managers[0].machine_ids
  node_count  = var.manager_count
  globals     = local.globals
}

module "elb_msr" {
  source      = "./modules/elb"
  count       = local.msr_count == 0 ? 0 : 1
  component   = "msr"
  ports       = ["443"]
  machine_ids = module.msrs[0].machine_ids
  node_count  = local.msr_count
  globals     = local.globals
}

module "managers" {
  source             = "./modules/manager"
  count              = var.manager_count == 0 ? 0 : 1
  node_role          = "manager"
  node_count         = var.manager_count
  node_instance_type = var.manager_type
  node_volume_size   = var.manager_volume_size
  controller_port    = local.controller_port
  globals            = local.globals
}

module "workers" {
  source             = "./modules/worker"
  count              = local.worker_count == 0 ? 0 : 1
  node_role          = "worker"
  node_count         = local.worker_count
  node_instance_type = var.worker_type
  node_volume_size   = var.worker_volume_size
  globals            = local.globals
}

module "msrs" {
  source             = "./modules/msr"
  count              = local.msr_count == 0 ? 0 : 1
  node_role          = "msr"
  node_count         = local.msr_count
  node_instance_type = var.msr_type
  node_volume_size   = var.msr_volume_size
  globals            = local.globals
}

module "windows_workers" {
  source             = "./modules/windows_worker"
  count              = var.windows_worker_count == 0 ? 0 : 1
  node_role          = "worker"
  node_count         = var.windows_worker_count
  node_instance_type = var.worker_type
  node_volume_size   = var.win_worker_volume_size
  image_id           = module.common.windows_2019_image_id
  win_admin_password = var.windows_administrator_password
  globals            = local.globals
}

# get our (client) id
data "aws_caller_identity" "current" {}

locals {
  cluster_name       = var.cluster_name == "" ? random_string.random.result : var.cluster_name
  expire             = timeadd(time_static.now.rfc3339, var.expire_duration)
  kube_orchestration = var.kube_orchestration ? "--default-node-orchestrator=kubernetes" : ""
  ami_obj            = var.platforms[var.platform_repo][var.platform]
  ami_obj_win        = var.platforms[var.platform_repo][var.win_platform]
  user_id            = data.aws_caller_identity.current.user_id
  account_id         = data.aws_caller_identity.current.account_id
  msr_install_flags  = concat(
                        var.msr_install_flags,
                        [try("--dtr-external-url=${module.elb_msr[0].lb_dns_name}", null)]
                       )

  msr_version_major = tonumber(split(".", var.msr_version)[0])
  # if msr_version_major >= 3 then:
  # add the msr_count onto worker_count, and set msr_count to 0
  # These changes keep MSR 3+ deployment configs out of launchpad.yaml
  worker_count      = local.msr_version_major == 2 ? var.worker_count : var.worker_count + var.msr_count
  msr_count         = local.msr_version_major == 2 ? var.msr_count : 0

  platform_details_map = {
    "centos" : "Linux/UNIX",
    "oracle" : "Linux/UNIX",
    "rhel" : "Red Hat Enterprise Linux",
    "rocky" : "Linux/UNIX",
    "sles" : "SUSE Linux",
    "ubuntu" : "Linux/UNIX",
    "windows" : "Windows"
  }
  distro = split("_", var.platform)[0]

  global_tags_nokube = merge(
    { # excludes kube-specific tags
      "Name"         = local.cluster_name
      "project"      = var.project
      "platform"     = var.platform
      "win_platform" = var.win_platform
      "expire"       = local.expire
      "user_id"      = local.user_id
      "username"     = var.username
      "task_name"    = var.task_name
    },
    var.extra_tags
  )

  global_tags = merge(
    { # kube-specific tags
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    },
    local.global_tags_nokube
  )

  globals = {
    tags_nokube           = local.global_tags_nokube
    tags                  = local.global_tags
    distro                = local.distro
    platform_details      = local.platform_details_map[local.distro]
    subnet_count          = length(module.vpc.public_subnet_ids)
    az_names_count        = length(module.vpc.az_names)
    spot_price_multiplier = 1 + (var.pct_over_spot_price / 100)
    pct_over_spot_price   = var.pct_over_spot_price
    vpc_id                = module.vpc.id
    cluster_name          = local.cluster_name
    subnet_ids            = module.vpc.public_subnet_ids
    az_names              = module.vpc.az_names
    security_group_id     = module.common.security_group_id
    image_id              = module.common.image_id
    root_device_name      = module.common.root_device_name
    ssh_key               = local.cluster_name
    instance_profile_name = module.common.instance_profile_name
    project               = var.project
    platform              = var.platform
    win_platform          = var.win_platform
    expire                = local.expire
    iam_fleet_role        = "arn:aws:iam::${local.account_id}:role/aws-ec2-spot-fleet-role"
  }

  # convert MKE install flags into a map
  mke_opts = { for f in var.mke_install_flags : trimprefix(element(split("=", f), 0), "--") => element(split("=", f), 1) }
  # discover if there is a controller port override.
  controller_port = try(
    local.mke_opts.controller_port,
    "443"
  )
  # Pick a path for saving the RSA private key
  key_path = var.ssh_key_file_path == "" ? "${path.root}/ssh_keys/${local.cluster_name}.pem" : var.ssh_key_file_path

  # Build a list of all machine hosts used in the cluster.
  # @NOTE This list is a meta structure that contains all of the host info used
  #    to build constructs such as the ansible hosts file, the launchpad yaml
  #    or the PRODENG toolbox config
  #
  hosts_linux = concat(
    var.manager_count == 0 ? [] : [
      for host in module.managers[0].instances : {
        instance = host.instance
        ami : local.ami_obj
        role = "manager"
        # @TODO put this into the template, not here
        ssh = {
          address = host.instance.public_ip
          user    = local.ami_obj.user
          keyPath = local.key_path
        }
        hooks = {
          apply = {
            before = var.hooks_apply_before
            after  = var.hooks_apply_after
          }
        }
      }
    ],
    local.worker_count == 0 ? [] : [
      for host in module.workers[0].instances : {
        instance = host.instance
        ami : local.ami_obj
        role = "worker"
        # @TODO put this into the template, not here
        ssh = {
          address = host.instance.public_ip
          user    = local.ami_obj.user
          keyPath = local.key_path
        }
        hooks = {
          apply = {
            before = var.hooks_apply_before
            after  = var.hooks_apply_after
          }
        }
      }
    ],
    local.msr_count == 0 ? [] : [
      for host in module.msrs[0].instances : {
        instance = host.instance
        ami : local.ami_obj
        role = "msr"
        # @TODO put this into the template, not here
        ssh = {
          address = host.instance.public_ip
          user    = local.ami_obj.user
          keyPath = local.key_path
        }
        hooks = {
          apply = {
            before = var.hooks_apply_before
            after  = var.hooks_apply_after
          }
        }
      }
    ]
  )
  hosts_win = var.windows_worker_count == 0 ? [] : [
    for host in module.windows_workers[0].instances : {
      instance = host.instance
      ami : local.ami_obj_win
      role = "worker"
      # @TODO put this into the template, not here
      winrm = {
        address  = host.instance.public_ip
        user     = local.ami_obj_win.user
        password = var.windows_administrator_password
        useHTTPS = true
        insecure = true
      }
    }
  ]
  hosts = concat(
    local.hosts_linux,
    local.hosts_win
  )

}

# Verify node Ready state post-cloud-init
# @NOTE Remote ssh into each node and verify that cloud-init
#    has completed, prior to concluding terraform run.
#    Safeguards against launchpad starting prior to user-init
#    completing.
resource "null_resource" "cluster" {
  triggers = {
    cluster_instance_ids = join(",", local.hosts_linux.*.instance.id)
  }
  count = length(local.hosts_linux)

  connection {
    type        = "ssh"
    host        = local.hosts_linux[count.index].instance.public_ip
    user        = local.ami_obj.user
    private_key = file(local.key_path)
    agent       = false
  }
  provisioner "remote-exec" {
    inline = [
    "sudo cloud-init status --wait"
    ]
  }
}
