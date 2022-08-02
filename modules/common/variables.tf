variable "cluster_name" {}

variable "global_tags" {
  description = "Map of global tags."
}

variable "vpc_id" {}

variable "ami_obj" {}

variable "ami_obj_win" {}

variable "controller_port" {}

variable "key_path" {}

variable "open_sg_for_myip" {
  type        = bool
  default     = false
  description = "If true, trust all traffic, any protocol, originating from the terraform execution source IP."
}
