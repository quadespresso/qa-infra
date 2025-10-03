variable "ports" {
  type = map(string)
  default = {
    443 : "443"
  }
  description = "Ports for the target groups."
}

variable "node_count" {
  type        = number
  default     = 0
  description = "Number of nodes in the cluster."
}

variable "node_ids" {
  type        = list(any)
  default     = []
  description = "List of node instance IDs."
}

variable "component" {
  type        = string
  default     = ""
  description = "Brief name of product component, ie, 'mke', 'msr'."
}

variable "globals" {
  type        = any
  description = "Map of global variables."
}
