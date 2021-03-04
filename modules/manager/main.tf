resource "aws_security_group" "manager" {
  name        = "${var.cluster_name}-managers"
  description = "mke cluster managers"
  vpc_id      = var.vpc_id

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
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  subnet_count          = length(var.subnet_ids)
  az_names_count        = length(var.az_names)
  spot_price_multiplier = 1 + (var.pct_over_spot_price / 100)
  tags = {
    "Name"                 = "${var.cluster_name}-manager"
    "Role"                 = "manager"
    (var.kube_cluster_tag) = "shared"
    "project"              = var.project
    "platform"             = var.platform
    "expire"               = var.expire
  }
  nodes = var.manager_count == 0 ? [] : [
    for k, v in zipmap(
      data.aws_instances.machines[0].public_ips,
      data.aws_instances.machines[0].private_ips
  ) : [k, v]]
}

data "aws_ec2_spot_price" "current" {
  count = local.az_names_count

  instance_type     = var.manager_type
  availability_zone = var.az_names[count.index]

  filter {
    name   = "product-description"
    values = [var.platform_details]
  }
}

data "template_file" "linux" {
  template = <<-EOF
  #!/bin/bash
  # Use fully qualified private DNS name for the host name.  Kube wants it this way.
  HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/hostname)
  echo $HOSTNAME > /etc/hostname
  sed -i "s|\(127\.0\..\.. *\)localhost|\1$HOSTNAME|" /etc/hosts
  hostname $HOSTNAME
  EOF
}

resource "aws_launch_template" "manager" {
  name                   = "${var.cluster_name}-manager"
  image_id               = var.image_id
  instance_type          = var.manager_type
  key_name               = var.ssh_key
  vpc_security_group_ids = [var.security_group_id, aws_security_group.manager.id]
  ebs_optimized          = true
  block_device_mappings {
    device_name = var.root_device_name
    ebs {
      volume_type = "gp2"
      volume_size = var.manager_volume_size
    }
  }
  user_data = base64encode(data.template_file.linux.rendered)
  tags      = local.tags
}

resource "aws_spot_fleet_request" "manager" {
  iam_fleet_role      = "arn:aws:iam::546848686991:role/aws-ec2-spot-fleet-role"
  allocation_strategy = "lowestPrice"
  target_capacity     = var.manager_count
  # valid_until     = "2019-11-04T20:44:20Z"
  wait_for_fulfillment                = true
  tags                                = local.tags
  terminate_instances_with_expiration = true

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.manager.id
      version = aws_launch_template.manager.latest_version
    }
    overrides {
      subnet_id = var.subnet_ids[0]
      spot_price = var.pct_over_spot_price == 0 ? null : format(
        "%f",
        data.aws_ec2_spot_price.current[0].spot_price * local.spot_price_multiplier
      )
    }
    overrides {
      subnet_id = var.subnet_ids[1]
      spot_price = var.pct_over_spot_price == 0 ? null : format(
        "%f",
        data.aws_ec2_spot_price.current[1].spot_price * local.spot_price_multiplier
      )
    }
    overrides {
      subnet_id = var.subnet_ids[2]
      spot_price = var.pct_over_spot_price == 0 ? null : format(
        "%f",
        data.aws_ec2_spot_price.current[2].spot_price * local.spot_price_multiplier
      )
    }
  }
}

data "aws_instances" "machines" {
  count = var.manager_count == 0 ? 0 : 1
  # we use this to collect the instance IDs from the spot fleet request
  filter {
    name   = "tag:aws:ec2spot:fleet-request-id"
    values = [aws_spot_fleet_request.manager.id]
  }
  instance_state_names = ["running", "pending"]
  depends_on           = [aws_spot_fleet_request.manager]
}

resource "aws_lb" "mke_manager" {
  name               = "${var.cluster_name}-manager-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  tags = local.tags
}

resource "aws_lb_target_group" "mke_manager_api" {
  name     = "${var.cluster_name}-api"
  port     = var.controller_port
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "mke_manager_api" {
  load_balancer_arn = aws_lb.mke_manager.arn
  port              = var.controller_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.mke_manager_api.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "mke_manager_api" {
  count            = var.manager_count
  target_group_arn = aws_lb_target_group.mke_manager_api.arn
  target_id        = data.aws_instances.machines[0].ids[count.index]
  port             = var.controller_port
}

resource "aws_lb_target_group" "mke_kube_api" {
  name     = "${var.cluster_name}-kube-api"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "mke_kube_api" {
  load_balancer_arn = aws_lb.mke_manager.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.mke_kube_api.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "mke_kube_api" {
  count            = var.manager_count
  target_group_arn = aws_lb_target_group.mke_kube_api.arn
  target_id        = data.aws_instances.machines[0].ids[count.index]
  port             = 6443
}
