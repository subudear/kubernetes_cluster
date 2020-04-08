variable "vpc_cidr_block" {}

variable aws_region {}

variable "domain" {}
variable "environment" {}
variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}


resource "aws_vpc" "vpc" {
    cidr_block=var.vpc_cidr_block
    enable_dns_hostnames = true
    enable_dns_support= true
	
	
    tags = {
        Name = "${var.cluster_name}"
		"Kubernetes.io/cluser/${var.cluster_name}" = "shared"
		"Terraform" = true
		"Environment" = "${var.environment}"
    }
	
	
}

resource "aws_route53_zone" "private" {
  name = var.domain

  vpc {
    vpc_id = "${aws_vpc.vpc.id}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}



output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "cidr_block" {
  value = aws_vpc.vpc.cidr_block
}

output "internet_gateway_id" {
  value = aws_internet_gateway.gw.id
}

output "hosted_zone_id" {
  value = aws_route53_zone.private.id
}

