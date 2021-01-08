output "lb_dns_name" {
  value = aws_lb.mke_manager.dns_name
}

output "public_ips" {
  value = aws_instance.mke_manager.*.public_ip
}

output "private_ips" {
  value = aws_instance.mke_manager.*.private_ip
}

output "machines" {
<<<<<<< HEAD:system_test_toolbox/launchpad/modules/manager/outputs.tf
  value = aws_instance.ucp_manager
}
=======
  value = aws_instance.mke_manager
}
>>>>>>> f7fcff6... Cumulative updates to Terraform config:launchpad/modules/manager/outputs.tf
