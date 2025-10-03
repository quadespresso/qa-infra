provider "aws" {
  region = var.aws_region
}

resource "random_string" "random" {
  length      = 6
  special     = false
  lower       = false
  min_upper   = 2
  min_numeric = 2
}

resource "time_static" "now" {}

resource "null_resource" "prepare_temp_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.temp_dir}"
  }
}

# create a temporary directory for TLS certs
# This directory will be deleted on destroy
resource "null_resource" "prepare_temp_tls_dir" {
  triggers = {
    path = "${local.temp_dir}/tls_cert"
  }

  # Create directory
  provisioner "local-exec" {
    command = "mkdir -p ${self.triggers.path}"
  }

  # Destroy-time cleanup
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up TLS temp directory: ${self.triggers.path}"
      rm -f ${self.triggers.path}/*
      rmdir ${self.triggers.path} || echo "Directory not empty or already removed"
    EOT
  }
}

# get image ID from platform name
module "ami" {
  source   = "./modules/ami"
  platform = var.platform
}

module "vpc" {
  source = "./modules/vpc"
  # host_cidr   = var.vpc_cidr
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.common_subnet_cidr
  global_tags = local.global_tags
}

module "efs" {
  source  = "./modules/efs"
  globals = local.globals
}

module "common" {
  source       = "./modules/common"
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.id
  # ami_obj          = local.ami_obj
  # ami_obj_win      = local.ami_obj_win
  key_path      = local.key_path
  ssh_algorithm = local.ssh_algorithm
  # open_sg_for_myip = var.open_sg_for_myip
  controller_port = local.controller_port
  global_tags     = local.global_tags
}

module "elb_mke" {
  source    = "./modules/elb"
  component = "mke"
  ports = {
    # 443 : local.controller_port,
    # 6443 : "6443",
    (local.controller_port) : local.controller_port,
    6443 : "6443",
    (var.ingress_https_port) : var.ingress_https_port
    8132 : "8132"
    9443 : "9443"
  }
  node_ids   = local.managers.node_ids
  node_count = var.manager_count
  globals    = local.globals
}

module "elb_mke4" {
  source    = "./modules/elb"
  component = "mke4"
  ports = {
    443 : var.ingress_https_port,
    6443 : "6443",
    8132 : "8132",
    9443 : "9443",
  }
  node_ids   = local.managers.node_ids
  node_count = var.manager_count
  globals    = local.globals
}

module "elb_msr" {
  source    = "./modules/elb"
  component = "msr"
  ports = {
    443 : var.msr_target_port
  }
  # For MSR 3 and 4, we only have one set of workers instead of msr dedicated nodes,
  # so direct traffic to the workers.  More on TESTING-2305
  # node_ids   = startswith(var.msr_version, "2") ? local.msrs.node_ids : local.workers.node_ids
  node_ids = (
    startswith(var.msr_version, "2") ?
    (var.msr_count == 0 ? [] : module.msrs.node_ids) :
    (var.worker_count == 0 ? [] : module.workers.node_ids)
  )
  node_count = (
    startswith(var.msr_version, "2") ?
    local.msr_count :
    local.worker_count
  )

  globals = local.globals
}

module "managers" {
  source        = "./modules/linux"
  role          = "manager"
  node_count    = var.manager_count
  instance_type = var.manager_type
  # life_cycle    = "ondemand"
  volume_size = var.manager_volume_size
  enable_fips = var.enable_fips
  globals     = local.globals
}

module "workers" {
  source        = "./modules/linux"
  role          = "worker"
  node_count    = local.worker_count
  instance_type = var.worker_type
  # life_cycle    = "ondemand"
  volume_size = var.worker_volume_size
  enable_fips = var.enable_fips
  globals     = local.globals
}

module "msrs" {
  source        = "./modules/linux"
  role          = "msr"
  node_count    = local.msr_count
  instance_type = var.msr_type
  # life_cycle    = "ondemand"
  volume_size = var.msr_volume_size
  enable_fips = var.enable_fips
  globals     = local.globals
}

module "windows_workers" {
  source        = "./modules/windows"
  role          = "worker"
  node_count    = var.windows_worker_count
  instance_type = var.worker_type
  # life_cycle         = "ondemand"
  volume_size        = var.win_worker_volume_size
  enable_fips        = var.enable_fips
  win_admin_password = var.win_admin_password
  globals            = local.globals
}

# get our (client) id
data "aws_caller_identity" "current" {}

locals {
  cluster_name  = var.cluster_name == "" ? random_string.random.result : var.cluster_name
  expire        = timeadd(time_static.now.rfc3339, var.expire_duration)
  platforms_map = jsondecode(file("${path.root}/etc/platforms.json"))
  # ami_obj       = local.platforms_map[var.platform]
  ami_obj_win = local.platforms_map[var.win_platform]
  default_platform = {
    "linux"   = var.platform
    "windows" = var.win_platform
  }
  user_id    = data.aws_caller_identity.current.user_id
  account_id = data.aws_caller_identity.current.account_id
  msr_install_flags = concat(
    var.msr_install_flags,
    [try("--dtr-external-url=${local.elb_msr.lb_dns_name}", "")],
  )

  # set MSR version to token value if var.msr_version is empty string
  msr_version_major = var.msr_version == "" ? 999 : tonumber(split(".", var.msr_version)[0])
  # if msr_version_major >= 3 then:
  # add the msr_count onto worker_count, and set msr_count to 0
  # These changes keep MSR 3+ deployment configs out of launchpad.yaml
  worker_count = local.msr_version_major == 2 ? var.worker_count : var.worker_count + var.msr_count
  msr_count    = local.msr_version_major == 2 ? var.msr_count : 0

  # managers        = var.manager_count == 0 ? [] : module.managers
  # workers         = var.worker_count == 0 ? [] : module.workers
  # msrs            = var.msr_count == 0 ? [] : module.msrs
  # windows_workers = var.windows_worker_count == 0 ? [] : module.windows_workers
  managers        = var.manager_count == 0 ? null : module.managers
  workers         = var.worker_count == 0 ? null : module.workers
  msrs            = var.msr_count == 0 ? null : module.msrs
  windows_workers = var.windows_worker_count == 0 ? null : module.windows_workers
  elb_msr         = var.msr_count == 0 ? null : module.elb_msr
  efs = (
    local.msr_count > 0
    ) || (
    local.msr_version_major >= 3
  ) ? module.efs : null

  ssh_algorithm = var.windows_worker_count > 0 ? "RSA" : var.ssh_algorithm

  distro = split("_", var.platform)[0]

  global_tags_nokube = merge(
    { # excludes kube-specific tags
      "Name"      = local.cluster_name
      "project"   = var.project
      "platform"  = var.platform
      "expire"    = local.expire
      "lifecycle" = "ondemand"
      "user_id"   = local.user_id
      "username"  = var.username
      "task_name" = var.task_name
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
    tags_nokube       = local.global_tags_nokube
    tags              = local.global_tags
    distro            = local.distro
    vpc_id            = module.vpc.id
    cluster_name      = local.cluster_name
    subnet_id         = module.vpc.public_subnet_id
    region            = var.aws_region
    security_group_id = module.common.security_group_id
    ssh_key           = local.cluster_name
    key_path          = local.key_path
    instance_profile  = module.common.instance_profile
    project           = var.project
    platform          = var.platform
    win_platform      = var.win_platform
    default_platform  = local.default_platform
    role_platform     = var.role_platform
    expire            = local.expire
    iam_fleet_role    = "arn:aws:iam::${local.account_id}:role/AmazonEC2SpotFleetTaggingRole"
  }

  # Set MKE orchestration (non-conflicting flags)
  kube_orchestration  = "--default-node-orchestrator=kubernetes"
  swarm_orchestration = "--default-node-orchestrator=swarm"
  node_orchestrators  = [local.kube_orchestration, local.swarm_orchestration]
  swarm_only          = "--swarm-only"
  contains_swarm_only = contains(var.mke_install_flags, local.swarm_only)
  contains_swarm_mode = contains(var.mke_install_flags, local.swarm_orchestration)
  # If --swarm-only explicitly set, remove all other flags.
  # Else if --default-node-orchestrator=swarm explicitly set, remove --default-node-orchestrator=kubernetes
  # Else default to --default-node-orchestrator=kubernetes, regardless of whether it was specified or not.
  sanitize_mke_install_flags = (
    local.contains_swarm_only ?
    setsubtract(var.mke_install_flags, local.node_orchestrators) :
    local.contains_swarm_mode ?
    setsubtract(var.mke_install_flags, [local.kube_orchestration]) :
    concat(var.mke_install_flags, [local.kube_orchestration])
  )
  # End set MKE orchestration

  # Let's ensure we don't have duplicate MKE install flags
  # mke_install_flags = distinct(local.sanitize_mke_install_flags)
  mke_install_flags = distinct(concat(tolist(local.sanitize_mke_install_flags), ["--nodeport-range=${var.node_port_range}"]))

  # convert MKE install flags into a map
  mke_opts = { for f in local.mke_install_flags : trimprefix(element(split("=", f), 0), "--") => element(split("=", f), 1) }
  # discover if there is a controller port override.
  controller_port = try(
    local.mke_opts.controller_port,
    "443"
  )

  # Pick a path for saving the RSA private key
  key_path = var.ssh_key_file_path == "" ? "${path.root}/ssh/${local.cluster_name}.pem" : var.ssh_key_file_path

  # Build a list of all machine hosts used in the cluster.
  # @NOTE This list is a meta structure that contains all of the host info used
  #    to build constructs such as the ansible hosts file, the launchpad yaml
  #    or the PRODENG toolbox config
  #
  hosts_linux = concat(
    var.manager_count == 0 ? [] : [
      for host in local.managers.instances : {
        instance = host
        # ami : local.ami_obj
        role = "manager"
        # @TODO put this into the template, not here
        ssh = {
          address = host.public_ip
          user    = local.managers.user
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
      for host in local.workers.instances : {
        instance = host
        # ami : local.ami_obj
        role = "worker"
        # @TODO put this into the template, not here
        ssh = {
          address = host.public_ip
          user    = local.workers.user
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
      for host in local.msrs.instances : {
        instance = host
        # ami : local.ami_obj
        role = "msr"
        # @TODO put this into the template, not here
        ssh = {
          address = host.public_ip
          user    = local.msrs.user
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
    for host in local.windows_workers.instances : {
      instance = host
      ami : local.ami_obj_win
      role = "worker"
      # @TODO put this into the template, not here
      winrm = {
        address  = host.public_ip
        user     = local.ami_obj_win.user
        password = var.win_admin_password
        useHTTPS = true
        insecure = true
      }
    }
  ]
  hosts = concat(
    local.hosts_linux,
    local.hosts_win
  )
  #   temp_dir for any file that will be deleted upon destroy
  temp_dir = "${path.root}/.terraform_temp"
}


# Generate the OpenSSL configuration file and TLS certificate for MSR4
module "tls" {
  count           = local.elb_msr != null ? 1 : 0
  source          = "./modules/tls"
  msr_common_name = local.elb_msr.lb_dns_name
  cert_path       = "${local.temp_dir}/tls_cert"
  cert_conf_name  = "msr-openssl.conf"
  cert_key_name   = "msr.key"
  cert_crt_name   = "msr.crt"
  depends_on      = [null_resource.prepare_temp_dir, null_resource.prepare_temp_tls_dir]
}


resource "null_resource" "mke4yaml" {
  triggers = {
    # This will force the local-exec provisioner to run on every terraform apply
    apply_trigger = timestamp()
  }

  provisioner "local-exec" {
    when    = create
    command = "${abspath(path.root)}/scripts/mke4_generator.sh"

    environment = {
      AIRGAP               = var.airgap
      LB                   = module.elb_mke4.lb_dns_name
      NODE_PORT_RANGE      = var.node_port_range
      INGRESS_HTTP_PORT    = var.ingress_http_port
      INGRESS_HTTPS_PORT   = var.ingress_https_port
      DEV_REGISTRY_ENABLED = var.dev_registries
      HOSTS = jsonencode([
        for h in local.hosts : {
          ssh = {
            address = h.ssh.address
            user    = h.ssh.user
            keyPath = abspath(h.ssh.keyPath)
            port    = 22
          }
          role = h.role == "manager" ? "controller+worker" : "worker"
        }
      ])
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f mke4.yaml"
  }
}
