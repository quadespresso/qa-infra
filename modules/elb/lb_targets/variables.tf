variable "listen_port" {
  type        = string
  default     = "443"
  description = "Port for the listener."
}

variable "target_port" {
  type        = string
  default     = "443"
  description = "Port for the target group."
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

variable "arn" {
  type        = string
  default     = ""
  description = "LB-specific ARN"
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "LB-specific map of tags"
}
