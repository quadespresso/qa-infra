terraform {
  required_version = ">= 1.4.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, !=5.39"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">=2.3.7"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.4"
    }
  }
}
