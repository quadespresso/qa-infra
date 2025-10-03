resource "tls_private_key" "tls_ed25519" {
  algorithm = "ED25519"
}

resource "tls_private_key" "tls_rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  # choose between ED25519 and RSA
  ssh_key = (
    var.ssh_algorithm == "ED25519" ?
    tls_private_key.tls_ed25519 :
    tls_private_key.tls_rsa
  )
}

resource "local_file" "ssh_private_key" {
  content  = local.ssh_key.private_key_openssh
  filename = var.key_path
  provisioner "local-exec" {
    command = "chmod 0600 ${local_file.ssh_private_key.filename}"
  }
}

resource "aws_key_pair" "key" {
  key_name   = var.cluster_name
  public_key = local.ssh_key.public_key_openssh
  tags       = var.global_tags
}

data "http" "ip_service" {
  url = "https://checkip.amazonaws.com/"
}

resource "aws_security_group" "common" {
  name        = "${var.cluster_name}-common"
  description = "mke cluster common rules"
  vpc_id      = var.vpc_id
  tags        = var.global_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_self" {
  description                  = "Allow all traffic originating from within the security group"
  security_group_id            = aws_security_group.common.id
  referenced_security_group_id = aws_security_group.common.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  description       = "Allow traffic to ssh"
  security_group_id = aws_security_group.common.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_mke_controller" {
  description       = "Allow traffic to MKE controller port"
  security_group_id = aws_security_group.common.id
  from_port         = var.controller_port
  to_port           = var.controller_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_8443" {
  description       = "Allow traffic to port 8443"
  security_group_id = aws_security_group.common.id
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_kube_api" {
  description       = "Allow traffic to the kube API"
  security_group_id = aws_security_group.common.id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_rdp" {
  description       = "Allow traffic to MSFT RDP"
  security_group_id = aws_security_group.common.id
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  description       = "Allow traffic to HTTPS"
  security_group_id = aws_security_group.common.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_winrm" {
  description       = "Allow traffic to WinRM"
  security_group_id = aws_security_group.common.id
  from_port         = 5985
  to_port           = 5986
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_mke4k_ui" {
  description       = "Allow traffic to MKE4k web UI"
  security_group_id = aws_security_group.common.id
  from_port         = 33000
  to_port           = 33001
  ip_protocol       = "tcp"
  # cidr_ipv4 = "${chomp(data.http.ip_service.response_body)}/32"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_nodeport_range" {
  description       = "Allow traffic to nodeport range"
  security_group_id = aws_security_group.common.id
  from_port         = 32768
  to_port           = 35535
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.ip_service.response_body)}/32"
}


resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  description       = "Allow traffic everywhere"
  security_group_id = aws_security_group.common.id
  from_port         = 0
  to_port           = 0
  ip_protocol       = "tcp"
  # cidr_ipv4 = "${chomp(data.http.ip_service.response_body)}/32"
  cidr_ipv4 = "0.0.0.0/0" # trivy:ignore:AVD-AWS-0104
}

# Leaving this here for now, as TEST-1655 may find some use for it.
# resource "aws_security_group_rule" "open_myip" {
#   # conditionally add this rule to SG 'common'
#   security_group_id = aws_security_group.common.id
#   count             = var.open_sg_for_myip ? 1 : 0
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   # cidr_blocks       = ["${chomp(data.external.ip_service.result["ip"])}/32"]
#   cidr_blocks       = ["${chomp(data.http.ip_service.response_body)}/32"]
#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_iam_role" "mke_role" {
  name               = "${var.cluster_name}_MKE_role"
  tags               = var.global_tags
  assume_role_policy = file("${path.module}/mke_role.json")
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.cluster_name}_MKE_profile"
  role = aws_iam_role.mke_role.name
}

resource "aws_iam_role_policy" "mke_policy" {
  name = "${var.cluster_name}_MKE_policy"
  role = aws_iam_role.mke_role.id
  # Ref: https://docs.mirantis.com/mke/3.6/install/install-aws/aws-prerequisites.html
  policy = file("${path.module}/mke_policy.json")
}

# Pulling from the data source saves us trying to attach to the policy.
# Problematic for 'docker-testing', even if not a problem for 'IAM_config_access'.
# This approach lets us pull the data from the policy and use it to create the
# 'ebs_csi_driver_policy', below. Avoids needing users to have more privs than
# necessary.
data "aws_iam_policy" "AmazonEBSCSIDriverPolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy" "ebs_csi_driver_policy" {
  name   = "${var.cluster_name}_EBSCSIDriverPolicy"
  role   = aws_iam_role.mke_role.id
  policy = data.aws_iam_policy.AmazonEBSCSIDriverPolicy.policy
}
