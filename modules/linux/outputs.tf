output "node_ids" {
  value = module.spot.node_ids
}

output "instances" {
  value = local.instances
}

output "user" {
  value = module.ami.user
}
