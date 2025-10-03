terraform {
  required_version = ">= 1.4.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, !=5.39"
    }
  }
}

variable "platform" {
  type        = string
  default     = "ubuntu_24.04"
  description = "Simple platform name, eg, 'ubuntu_24.04' - see .../etc/platforms.json for full reference."
}

### main

locals {
  platforms_map = jsondecode(file("${path.root}/etc/platforms.json"))
  ami_obj       = local.platforms_map[var.platform]
}

data "aws_ami" "image" {
  most_recent = true
  owners      = [local.ami_obj.owner]
  filter {
    name   = "name"
    values = [local.ami_obj.ami_name]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

### output

output "image_id" {
  value = data.aws_ami.image.id
}

# login name for platform
output "user" {
  value = local.ami_obj.user
}
