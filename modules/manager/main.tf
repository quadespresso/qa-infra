locals {
  node_role = {
      "Name" = "${var.globals.cluster_name}-${var.node_role}"
      "Role" = var.node_role
    }
  tags = merge(
    var.globals.tags,
    local.node_role
  )
  tags_nokube = merge(
    var.globals.tags_nokube,
    local.node_role
  )
  os_type = "linux"
}

resource "aws_security_group" "node" {
  name        = "${var.globals.cluster_name}-${var.node_role}s"
  description = "MKE cluster ${var.node_role}s"
  vpc_id      = var.globals.vpc_id
  tags        = local.tags_nokube

  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port   = var.controller_port
    to_port     = var.controller_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "spot" {
  source        = "../spot"
  globals       = var.globals
  node_count    = var.node_count
  instance_type = var.node_instance_type
  node_role     = var.node_role
  volume_size   = var.node_volume_size
  asg_node_id   = aws_security_group.node.id
  os_type       = local.os_type
  efs_dns       = var.efs_dns
  tags          = local.tags
}
