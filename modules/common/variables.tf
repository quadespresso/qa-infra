variable "cluster_name" {
  type        = string
  default     = ""
  description = "Global cluster name. Use this to override a dynamically created name."
  validation {
    condition     = length(var.cluster_name) < 11
    error_message = "Length of cluster_name cannot exceed 10 characters"
  }
}

variable "global_tags" {
  type        = map(any)
  default     = {}
  description = "Map of global tags."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC ID"
}

variable "controller_port" {
  type        = string
  default     = "443"
  description = "Controller port number"
}

variable "key_path" {
  type        = string
  default     = ""
  description = "Path to the local ssh private key"
}

variable "ssh_algorithm" {
  type        = string
  default     = "ED25519"
  description = "Choose between ED25519 and RSA."
}
