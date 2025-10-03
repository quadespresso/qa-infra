terraform {
  required_version = ">= 1.4.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, !=5.39"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.5.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.1.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">=3.5.0"
    }
  }
}
