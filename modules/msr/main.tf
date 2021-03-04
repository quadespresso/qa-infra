resource "aws_security_group" "msr" {
  name        = "${var.cluster_name}-msrs"
  description = "mke cluster msrs"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  subnet_count          = length(var.subnet_ids)
  az_names_count        = length(var.az_names)
  spot_price_multiplier = 1 + (var.pct_over_spot_price / 100)
  tags = {
    "Name"                 = "${var.cluster_name}-msr"
    "Role"                 = "msr"
    (var.kube_cluster_tag) = "shared"
    "project"              = var.project
    "platform"             = var.platform
    "expire"               = var.expire
  }
  nodes = var.msr_count == 0 ? [] : [
    for k, v in zipmap(
      data.aws_instances.machines[0].public_ips,
      data.aws_instances.machines[0].private_ips
  ) : [k, v]]
}

data "aws_ec2_spot_price" "current" {
  count = local.az_names_count

  instance_type     = var.msr_type
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

###

resource "aws_launch_template" "msr" {
  name                   = "${var.cluster_name}-msr"
  image_id               = var.image_id
  instance_type          = var.msr_type
  key_name               = var.ssh_key
  vpc_security_group_ids = [var.security_group_id, aws_security_group.msr.id]
  ebs_optimized          = true
  block_device_mappings {
    device_name = var.root_device_name
    ebs {
      volume_type = "gp2"
      volume_size = var.msr_volume_size
    }
  }
  user_data = base64encode(data.template_file.linux.rendered)
  tags      = local.tags
}

resource "aws_spot_fleet_request" "msr" {
  iam_fleet_role      = "arn:aws:iam::546848686991:role/aws-ec2-spot-fleet-role"
  allocation_strategy = "lowestPrice"
  target_capacity     = var.msr_count
  # valid_until     = "2019-11-04T20:44:20Z"
  wait_for_fulfillment                = true
  tags                                = local.tags
  terminate_instances_with_expiration = true

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.msr.id
      version = aws_launch_template.msr.latest_version
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
  count = var.msr_count == 0 ? 0 : 1
  # we use this to collect the instance IDs from the spot fleet request
  filter {
    name   = "tag:aws:ec2spot:fleet-request-id"
    values = [aws_spot_fleet_request.msr.id]
  }
  instance_state_names = ["running", "pending"]
  depends_on           = [aws_spot_fleet_request.msr]
}
