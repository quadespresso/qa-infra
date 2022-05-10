
terraform {
  required_providers {
    tls = {
      source = "hashicorp/tls"
      version = ">= 3.2.0"
    }
  }
  required_version = ">= 0.14"
}
