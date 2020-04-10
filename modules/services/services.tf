variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "aws_region" {}

variable vpc_id {}

variable "vpc_cidr_block" {}

variable kops_state_bucket_name {}

variable environment {}

variable "domain" {}

variable "cluster_name" {}

variable internet_gateway_id {}

variable aws_account_id {}



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
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index+3)
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
