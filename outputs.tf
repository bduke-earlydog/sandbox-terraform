output "vpc_id" {
  value = module.network.vpc_id
}

output "subnets_ids" {
  value = module.network.subnet_ids
}

output "nat_ips" {
  value = module.network.nat_ips
}