variable "global_tags" {
  description = "Map of global tags."
}

# variable "host_cidr" {
#   description = "CIDR IPv4 range to assign to EC2 nodes"
#   default     = "172.31.0.0/16"
# }


variable "vpc_cidr" {
  description = "CIDR IPv4 range to assign to VPC"
}

variable "subnet_cidr" {
  description = "CIDR IPv4 range to assign to subnet"
}
