output "region" {
	value = "${data.aws_region.current.name}"
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "aws_account_id" {
	value = "${var.aws_account_id}"
}

output rds_instance_endpoint {
	value = module.services.rds_instance_endpoint
}

output redis_elasticache_endpoint {
	value = module.services.redis_elasticache_endpoint
}


output "internet_gateway_id" {
  value = module.network.internet_gateway_id
}

output "hosted_zone_id" {
  value = module.network.hosted_zone_id
}

output "availability_zone_names" {
  value = module.services.availability_zone_names
}

output "vpc_cidr_block" {
  value = module.network.cidr_block
}

output "kops_private_subnet_cidr" {
   
  value = module.services.kops_subnet_private_cidr
}

output "kops_private_subnet_ids" {
  value = module.services.kops_subnet_private_ids
}

output "elastic_ips" {  
  value = module.services.elastic_ips
}

output "nat_gateways" {  
  value = module.services.nat_gateways
}

output "bastion_public_subnet_cidr" {
   
  value = module.services.bastion_subnet_public_cidr
}

output "bastion_public_subnet_ids" {
  value = module.services.bastion_subnet_public_ids
}

output "kops_private_route_table_ids" {
  value = module.services.kops_private_route_table_ids
}

output "bastion_public_route_table_ids" {
  value = module.services.bastion_public_route_table_ids
}

output "cluster_name" {
	value = "${var.cluster_name}"
}

output "kops_s3_bucket" {
  value = module.services.kops_s3_bucket
  }