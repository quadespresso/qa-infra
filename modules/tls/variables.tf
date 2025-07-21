# CN of the load balancer
# i.e. k4mdq7-msr-lb-18683f13e75b7188.elb.us-west-2.amazonaws.com
variable "msr_common_name" {
  type = string
}

# location for cert files to be created
variable "cert_conf_name" {
  type = string
}

# file name for the private key
variable "cert_key_name" {
  type = string
}

# file name for the certificate
variable "cert_crt_name" {
  type = string
}

# location of tls related files
variable "cert_path" {
  type = string
}
