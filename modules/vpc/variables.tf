variable "global_tags" {
  type        = map(any)
  description = "Map of global tags."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR IPv4 range to assign to VPC"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR IPv4 range to assign to subnet"
}
