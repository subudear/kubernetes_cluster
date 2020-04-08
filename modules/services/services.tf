variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "aws_region" {}

variable vpc_id {}

variable "vpc_cidr_block" {}

variable rds_password {}

variable kops_state_bucket_name {}

variable environment {}

variable "domain" {}

variable "cluster_name" {}

variable internet_gateway_id {}

variable aws_account_id {}

variable "es_domain" {}



data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}


locals {
  az_names = data.aws_availability_zones.available.names
}

###############################################
# RESOURCES
###############################################

##################KOPS Subnet###########################

resource "aws_subnet" "kops-subnet-private" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = var.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index)
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "private-kops.${data.aws_availability_zones.available.names[count.index]}.${var.cluster_name}"
	"SubnetType" = "Private"
	"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	"kubernetes.io/role/internal-elb" = 1
  }
  
}

resource "aws_route_table" "private_kops" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = var.vpc_id
  route {
                cidr_block = "0.0.0.0/0"
                nat_gateway_id = "${aws_nat_gateway.ngw.*.id[count.index]}"
    }
  tags   = { Name = "kops_route_table_private_subnet.${var.cluster_name}"}
}

resource "aws_route_table_association" "private" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = "${aws_subnet.kops-subnet-private.*.id[count.index]}"
  route_table_id = "${aws_route_table.private_kops.*.id[count.index]}"

  lifecycle {
    ignore_changes        = [subnet_id]
    create_before_destroy = true
  }
}

##########################Bastion Subnet###################################################

resource "aws_subnet" "bastion-subnet-public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = var.vpc_id
  # cidr_block              = cidrsubnet(var.vpc_cidr_block, 3, parseint(var.kops_created_subnet_count, 10) + count.index)
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index+12)
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "utility.${data.aws_availability_zones.available.names[count.index]}.${var.cluster_name}"
	"SubnetType" = "Utility"
	"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	"kubernetes.io/role/elb" = 1
  }
}

resource "aws_route_table" "public_bastion" {
  vpc_id = var.vpc_id
  tags   = { Name = "public_subnet_route_table.${var.cluster_name}"}
}


resource "aws_route_table_association" "public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = "${aws_subnet.bastion-subnet-public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public_bastion.id}"

  lifecycle {
    ignore_changes        = [subnet_id, route_table_id]
    create_before_destroy = true
  }
}
###################################################
resource "aws_route" "internet_route" {
  route_table_id         = "${aws_route_table.public_bastion.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
	
  lifecycle {
    create_before_destroy = true
  }
  
}

resource "aws_db_subnet_group" "rds_db_subnet_group" {
  name       = "rds_db_subnet_group.${var.cluster_name}"
  subnet_ids = aws_subnet.kops-subnet-private.*.id
  tags = {
    Name = "rds_db_subnet_group.${var.cluster_name}"
  }
}

resource "aws_db_instance" "test-config-store" {
  identifier                      = "test-config-store-${replace(var.cluster_name, ".", "-")}"
  allocated_storage               = 10
  auto_minor_version_upgrade      = true
  backup_retention_period         = 1
  backup_window                   = "03:30-04:00"
  copy_tags_to_snapshot           = false
  db_subnet_group_name            = aws_db_subnet_group.rds_db_subnet_group.name
  deletion_protection             = false
  enabled_cloudwatch_logs_exports = []
  engine                          = "postgres"
  iam_database_authentication_enabled   = false
  instance_class                        = "db.t3.medium"
  iops                                  = 0
  license_model                         = "postgresql-license"
  maintenance_window                    = "sat:06:04-sat:06:34"
  max_allocated_storage                 = 0
  monitoring_interval                   = 0
  multi_az                              = true
  name                                  = "postgres"
  option_group_name                     = "default:postgres-11"
  parameter_group_name                  = "default.postgres11"
  performance_insights_enabled          = false
  performance_insights_retention_period = 0
  port                                  = 5432
  publicly_accessible                   = false
  security_group_names                  = []
  skip_final_snapshot                   = true
  storage_encrypted                     = false
  storage_type                          = "standard"
  tags = {
    "Environment" = "test"
    "Product"     = "test-ClusterConfig"
  }
  username = "uAdmin"
  password = var.rds_password
  timeouts {}
}


# ElastiCache Assets - Redis


resource "aws_elasticache_subnet_group" "test-redis" {
  name       = "test-redis-cache-subnet"
  subnet_ids = aws_subnet.kops-subnet-private.*.id
}

resource "aws_security_group" "elasticache1" {
  name        = "security-group"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

resource "aws_elasticache_cluster" "test-redis" {
  cluster_id      = "test-redis-${replace(var.cluster_name, ".", "-")}"
  engine          = "redis"
  node_type       = "cache.t3.medium"
  num_cache_nodes = 1
  port            = 6379
  # transit_encryption_enabled = true
  subnet_group_name = aws_elasticache_subnet_group.test-redis.name
  depends_on        = [aws_elasticache_subnet_group.test-redis]
} 


# Elastic Search Assets

 resource "aws_security_group" "es" {
   name        = "elasticsearch-${var.domain}"
   description = "Managed by Terraform"
   vpc_id      = var.vpc_id

   ingress {
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = [var.vpc_cidr_block]
   }
 }



 resource "aws_elasticsearch_domain" "es" {
   domain_name           = var.es_domain
   cluster_config {
     instance_type = "t2.small.elasticsearch"
     instance_count= 2
     zone_awareness_enabled = true # need this to have > 1 subnet
   }

   ebs_options {
     ebs_enabled = true
     volume_size = 20
   }


   vpc_options {
     subnet_ids = aws_subnet.kops-subnet-private.*.id
     security_group_ids = [aws_security_group.es.id]
   }

   advanced_options = {
     "rest.action.multi.allow_explicit_index" = "true"
   }

   access_policies = <<CONFIG
 {
     "Version": "2012-10-17",
     "Statement": [
         {
             "Action": "es:*",
             "Principal": "*",
             "Effect": "Allow",
             "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.es_domain}/*"
         }
     ]
 }
 CONFIG

   snapshot_options {
     automated_snapshot_start_hour = 23
   }

   tags = {
     Domain = var.es_domain
   }


 }



# S3 bucket to store kops state.

resource "aws_s3_bucket" "kops_state" {
  bucket        = var.kops_state_bucket_name
  acl           = "private"
  force_destroy = true
  versioning {
    enabled = true
  }
  tags          = {
    Environment = var.environment
    Terraform = true
	Name = var.kops_state_bucket_name
  }
}

#######################elastic IPs##########################
resource "aws_eip" "nat" {
	count         = length(data.aws_availability_zones.available.names)
	vpc = true

	tags =     {
      Name = "natgw.${var.cluster_name}"
    }
}
#############################################################

###########################NAT Gateways######################
resource "aws_nat_gateway" "ngw" {
  count         = length(data.aws_availability_zones.available.names)
  allocation_id = "${aws_eip.nat.*.id[count.index]}"
  subnet_id     = "${aws_subnet.bastion-subnet-public.*.id[count.index]}"

  tags = {
    Name = "${var.cluster_name}-natgw"
  }
  depends_on = [var.internet_gateway_id]
}




####################OUTPUTS####################
/*
output ElasticSearch_Endpoint {
  value = aws_elasticsearch_domain.es.endpoint
}

output ElasticSearch_Kibana_Endpoint {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
*/
output rds_instance_endpoint {
	value = aws_db_instance.test-config-store.endpoint
}

output redis_elasticache_endpoint {
	value = aws_elasticache_cluster.test-redis.cache_nodes
}

output  availability_zone_names {
  value = data.aws_availability_zones.available.names
}

output elastic_ips {  
  value = aws_eip.nat.*.public_ip
}

output nat_gateways {  
  value = aws_nat_gateway.ngw.*.id
}

output kops_subnet_private_cidr {  
  value = aws_subnet.kops-subnet-private.*.cidr_block
}

output kops_subnet_private_ids {
  value = aws_subnet.kops-subnet-private.*.id
}


output bastion_subnet_public_cidr {
  
  value = aws_subnet.bastion-subnet-public.*.cidr_block
}

output bastion_subnet_public_ids {
  value = aws_subnet.bastion-subnet-public.*.id
}


output bastion_public_route_table_ids {
value = aws_route_table.public_bastion.id
}

output kops_private_route_table_ids {
value = aws_route_table.private_kops.*.id
}

output kops_s3_bucket {
  value = aws_s3_bucket.kops_state.bucket
}




