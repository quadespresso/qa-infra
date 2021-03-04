resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}-win-workers"
  description = "mke cluster windows workers"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  subnet_count          = length(var.subnet_ids)
  az_names_count        = length(var.az_names)
  spot_price_multiplier = 1 + (var.pct_over_spot_price / 100)
  tags = {
    "Name"                 = "${var.cluster_name}-win-worker"
    "Role"                 = "manager"
    (var.kube_cluster_tag) = "shared"
    "project"              = var.project
    "platform"             = var.platform
    "expire"               = var.expire
  }
  nodes = var.worker_count == 0 ? [] : [
    for k, v in zipmap(
      data.aws_instances.machines[0].public_ips,
      data.aws_instances.machines[0].private_ips
  ) : [k, v]]
}

data "aws_ec2_spot_price" "current" {
  count = local.az_names_count

  instance_type     = var.worker_type
  availability_zone = var.az_names[count.index]

  filter {
    name   = "product-description"
    values = ["Windows"]
  }
}

data "template_file" "windows" {
  template = <<-EOF
  <powershell>
  $admin = [adsi]("WinNT://./administrator, user")
  $admin.psbase.invoke("SetPassword", "${var.windows_administrator_password}")
  
  # Snippet to enable WinRM over HTTPS with a self-signed certificate
  # from https://gist.github.com/TechIsCool/d65017b8427cfa49d579a6d7b6e03c93
  Write-Output "Disabling WinRM over HTTP..."
  Disable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
  Disable-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC"
  Get-ChildItem WSMan:\Localhost\listener | Remove-Item -Recurse
  
  Write-Output "Configuring WinRM for HTTPS..."
  Set-Item -Path WSMan:\LocalHost\MaxTimeoutms -Value '1800000'
  Set-Item -Path WSMan:\LocalHost\Shell\MaxMemoryPerShellMB -Value '1024'
  Set-Item -Path WSMan:\LocalHost\Service\AllowUnencrypted -Value 'false'
  Set-Item -Path WSMan:\LocalHost\Service\Auth\Basic -Value 'true'
  Set-Item -Path WSMan:\LocalHost\Service\Auth\CredSSP -Value 'true'
  
  New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" `
      -DisplayName "Windows Remote Management (HTTPS-In)" `
      -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]" `
      -Group "Windows Remote Management" `
      -Program "System" `
      -Protocol TCP `
      -LocalPort "5986" `
      -Action Allow `
      -Profile Domain,Private
  
  New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP-PUBLIC" `
      -DisplayName "Windows Remote Management (HTTPS-In)" `
      -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP 5986]" `
      -Group "Windows Remote Management" `
      -Program "System" `
      -Protocol TCP `
      -LocalPort "5986" `
      -Action Allow `
      -Profile Public
  
  $Hostname = [System.Net.Dns]::GetHostByName((hostname)).HostName.ToUpper()
  $pfx = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $Hostname
  $certThumbprint = $pfx.Thumbprint
  $certSubjectName = $pfx.SubjectName.Name.TrimStart("CN = ").Trim()
  
  New-Item -Path WSMan:\LocalHost\Listener -Address * -Transport HTTPS -Hostname $certSubjectName -CertificateThumbPrint $certThumbprint -Port "5986" -force
  
  Write-Output "Restarting WinRM Service..."
  Stop-Service WinRM
  Set-Service WinRM -StartupType "Automatic"
  Start-Service WinRM
  </powershell>
  EOF
}

resource "aws_launch_template" "worker" {
  name                   = "${var.cluster_name}-win-worker"
  image_id               = var.image_id
  instance_type          = var.worker_type
  key_name               = var.ssh_key
  vpc_security_group_ids = [var.security_group_id, aws_security_group.worker.id]
  ebs_optimized          = true
  block_device_mappings {
    device_name = var.root_device_name
    ebs {
      volume_type = "gp2"
      volume_size = var.worker_volume_size
    }
  }
  connection {
    type     = "winrm"
    user     = "Administrator"
    password = var.administrator_password
    timeout  = "10m"
    https    = "true"
    insecure = "true"
    port     = 5986
  }
  user_data = base64encode(data.template_file.windows.rendered)
  tags      = local.tags
}

resource "aws_spot_fleet_request" "worker" {
  iam_fleet_role      = "arn:aws:iam::546848686991:role/aws-ec2-spot-fleet-role"
  allocation_strategy = "lowestPrice"
  target_capacity     = var.worker_count
  # valid_until     = "2019-11-04T20:44:20Z"
  wait_for_fulfillment                = true
  tags                                = local.tags
  terminate_instances_with_expiration = true

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.worker.id
      version = aws_launch_template.worker.latest_version
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
  count = var.worker_count == 0 ? 0 : 1
  # we use this to collect the instance IDs from the spot fleet request
  filter {
    name   = "tag:aws:ec2spot:fleet-request-id"
    values = [aws_spot_fleet_request.worker.id]
  }
  instance_state_names = ["running", "pending"]
  depends_on           = [aws_spot_fleet_request.worker]
}
