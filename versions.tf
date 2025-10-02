
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, !=5.39"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.7.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.13.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.5.3"
    }
  }
}
