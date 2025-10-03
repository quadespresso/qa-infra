terraform {
  required_version = ">= 1.4.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, !=5.39"
    }
  }
}

variable "globals" {
  type        = any
  description = "Map of global variables."
}

resource "aws_efs_file_system" "cluster" {
  encrypted = "true"
  tags      = var.globals.tags
}

resource "aws_efs_mount_target" "az" {
  file_system_id  = aws_efs_file_system.cluster.id
  subnet_id       = var.globals.subnet_id
  security_groups = [var.globals.security_group_id]
}

output "dns_name" {
  value = aws_efs_file_system.cluster.dns_name
}
