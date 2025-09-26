variable "username" {
  type        = string
  default     = "UNDEFINED"
  description = "A string which represents the engineer running the test."
  validation {
    condition     = length(var.username) < 31
    error_message = "Length of username cannot exceed 30 characters"
  }
}

variable "task_name" {
  type        = string
  default     = "UNDEFINED"
  description = "An arbitrary yet unique string which represents the deployment, eg, 'refactor', 'unicorn', 'stresstest'."
  validation {
    condition     = length(var.task_name) < 31
    error_message = "Length of task_name cannot exceed 30 characters"
  }
}

variable "project" {
  type        = string
  default     = "UNDEFINED"
  description = "One of the official cost-tracking project names. Without this, your cluster may get terminated without warning."
  validation {
    condition     = length(var.project) < 11
    error_message = "Length of project cannot exceed 10 characters"
  }
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "Global cluster name. Use this to override a dynamically created name."
  validation {
    condition     = length(var.cluster_name) < 11
    error_message = "Length of cluster_name cannot exceed 10 characters"
  }
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "A map of arbitrary, customizable string key/value pairs to be included alongside a preset map of tags to be used across myriad AWS resources."
}

variable "expire_duration" {
  type        = string
  default     = "120h"
  description = "The max time to allow this cluster to avoid early termination. Can use 'h', 'm', 's' in sane combinations, eg, '15h37m18s'."
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "The AWS region to deploy to."
}

variable "vpc_cidr" {
  type        = string
  default     = "172.31.0.0/16"
  description = "The CIDR to use when creating the VPC."
}

variable "common_subnet_cidr" {
  type        = string
  default     = "172.31.0.0/24"
  description = "The CIDR to use when creating the common subnet."
}

variable "airgap_subnet_cidr" {
  type        = string
  default     = "172.31.1.0/24"
  description = "The CIDR to use when creating the airgap subnet."
}

variable "admin_username" {
  type        = string
  default     = "admin"
  description = "The MKE admin username to use."
}

variable "admin_password" {
  type        = string
  default     = "orcaorcaorca"
  description = "The MKE admin password to use."
}

variable "manager_count" {
  type        = number
  description = "The number of MKE managers to create."
  validation {
    condition     = var.manager_count > 0
    error_message = "You deployment must have at least 1 manager node"
  }
}

variable "worker_count" {
  type        = number
  description = "The number of MKE Linux workers to create."
}

variable "msr_count" {
  type        = number
  description = "The number of MSR replicas to create."
}

variable "windows_worker_count" {
  type        = number
  description = "The number of MKE Windows workers to create."
}

variable "manager_type" {
  type        = string
  default     = "m5.xlarge"
  description = "The AWS instance type to use for manager nodes."
}

variable "worker_type" {
  type        = string
  default     = "m5.large"
  description = "The AWS instance type to use for Linux/Windows worker nodes."
}

variable "msr_type" {
  type        = string
  default     = "m5.xlarge"
  description = "The AWS instance type to use for MSR replica nodes."
}

variable "manager_volume_size" {
  type        = number
  default     = 100
  description = "The volume size (in GB) to use for manager nodes."
}

variable "worker_volume_size" {
  type        = number
  default     = 100
  description = "The volume size (in GB) to use for worker nodes."
}

variable "win_worker_volume_size" {
  type        = number
  default     = 50
  description = "The volume size (in GB) to use for Windows worker nodes."
}

variable "msr_volume_size" {
  type        = number
  default     = 50
  description = "The volume size (in GB) to use for MSR replica nodes."
}

variable "win_admin_password" {
  type        = string
  default     = "tfaws,,ABC..Example"
  description = "The Windows Administrator password to use."
}

variable "platform" {
  type        = string
  default     = "ubuntu_20.04"
  description = "The Linux platform to use for manager/worker/MSR replica nodes"
}

variable "win_platform" {
  type        = string
  default     = "windows_2019"
  description = "The Windows platform to use for worker nodes"
}

variable "mcr_version" {
  type        = string
  description = "The mcr version to deploy across all nodes in the cluster."
}

variable "mcr_channel" {
  type        = string
  description = "The channel to pull the mcr installer from."
}

variable "mcr_repo_url" {
  type        = string
  default     = "https://repos-internal.mirantis.com"
  description = "The repository to source the mcr installer."
}

variable "mcr_install_url_linux" {
  type        = string
  default     = "https://get.mirantis.com/"
  description = "Location of Linux installer script."
}

variable "mcr_install_url_windows" {
  type        = string
  default     = "https://get.mirantis.com/install.ps1"
  description = "Location of Windows installer script."
}

variable "mke_version" {
  type        = string
  description = "The MKE version to deploy."
}

variable "mke_image_repo" {
  type        = string
  default     = "msr.ci.mirantis.com/mirantiseng"
  description = "The repository to pull the MKE images from."
}

variable "mke_install_flags" {
  type        = list(string)
  default     = []
  description = "The MKE installer flags to use."
}

variable "kube_orchestration" {
  type        = bool
  default     = true
  description = "The option to enable/disable Kubernetes as the default orchestrator."
}

variable "msr_version" {
  type        = string
  default     = ""
  description = "The MSR version to deploy."
}

variable "msr_image_repo" {
  type        = string
  default     = "msr.ci.mirantis.com/msr"
  description = "The repository to pull the MSR images from."
}

variable "msr_install_flags" {
  type        = list(string)
  default     = ["--ucp-insecure-tls"]
  description = "The MSR installer flags to use."
}

variable "msr_replica_config" {
  type        = string
  default     = "sequential"
  description = "Set to 'sequential' to generate sequential replica id's for cluster members, for example 000000000001, 000000000002, etc. ('random' otherwise)"
}

variable "msr_enable_nfs" {
  type        = bool
  default     = true
  description = "Option to configure EFS/NFS for use with MSR 2.x"
}

variable "role_platform" {
  type = map(any)
  default = {
    "manager" = null
    "worker"  = null
    "msr"     = null
  }
  description = "Platform names based on role. Linux-only, Windows uses win_platform only."
}

variable "hooks_apply_before" {
  type        = list(string)
  default     = [""]
  description = "A list of strings (shell commands) to be run before stages."
}

variable "hooks_apply_after" {
  type        = list(string)
  default     = [""]
  description = "A list of strings (shell commands) to be run after stages."
}

variable "ssh_key_file_path" {
  type        = string
  default     = ""
  description = "If non-empty, use this path/filename as the ssh key file instead of generating automatically."
}

variable "ssh_algorithm" {
  type    = string
  default = "ED25519"
  validation {
    condition     = contains(["ED25519", "RSA"], var.ssh_algorithm)
    error_message = "Valid values for var 'ssh_algorithm' must be one of: 'RSA', 'ED25519'"
  }
}

variable "enable_fips" {
  type    = bool
  default = false
  validation {
    condition     = contains([true, false], var.enable_fips)
    error_message = "Valid values for var 'enable_fips' must be one of: 'true', 'false'"
  }
  description = "Enable FIPS mode on the cluster. Be mindful of 'ssh_algorithm' compatibility."
}

variable "open_sg_for_myip" {
  type        = bool
  default     = false
  description = "If true, allow ALL traffic, ANY protocol, originating from the terraform execution source IP. Use sparingly."
}

variable "ingress_controller_replicas" {
  type        = number
  default     = 2
  description = "Number of replicas for the ingress controller ('ingressController.replicaCount' in the MKE installer YAML file)."
}

variable "msr_target_port" {
  default     = "443"
  description = "The target port for MSR LoadBalancer should lead to this port on the MSR replicas."
}

variable "node_port_range" {
  type        = string
  default     = "32768-35535"
  description = "MKE 4 node port range specified in .spec.network.nodePortRange"
}

variable "ingress_https_port" {
  type        = string
  default     = "33001"
  description = "NodePort for Ingress Controller HTTPS traffic. MUST be within the node_port_range"
}

variable "ingress_http_port" {
  type        = string
  default     = "33000"
  description = "NodePort for Ingress Controller HTTP traffic. MUST be within the node_port_range"
}

variable "dex_http_port" {
  type        = string
  default     = "33336"
  description = "NodePort for Dex HTTP traffic. MUST be within the node_port_range"
}

variable "dex_https_port" {
  type        = string
  default     = "33334"
  description = "NodePort for Dex HTTPS traffic. MUST be within the node_port_range"
}

variable "dex_grpc_port" {
  type        = string
  default     = "33337"
  description = "NodePort for Dex gRPC traffic. MUST be within the node_port_range"
}

variable "airgap" {
  type        = bool
  default     = false
  description = "Whether to create an env without Internet access."
}

variable "bastion_type" {
  type        = string
  default     = "m5.xlarge"
  description = "The AWS instance type to use for bastion node in an airgapped env."
}

variable "bastion_volume_size" {
  type        = number
  default     = 100
  description = "The volume size (in GB) to use for bastion node in an airgapped env."
}

variable "dev_registries" {
  type        = bool
  default     = false
  description = "If true, the generated mke4.yaml will use ghcr registries instead of production registry.mirantis.com"
}
