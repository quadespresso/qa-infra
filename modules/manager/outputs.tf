output "machines" {
  value = module.spot.nodes
}

output "machine_ids" {
  value = module.spot.node_ids
}
