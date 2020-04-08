
variable "number_of_masters" { default = 3 }

data "aws_region" "current" {}


provider "aws" {
  region     = "${var.aws_region}"
}

terraform {
  backend "s3" {
    region = "ap-southeast-2"
    bucket = "terraform-s3-state-test"
    key    = "vpc/terraform.tfstate"
  }
}


module "network" {
  source         = "../modules/network/"
  aws_region     = var.aws_region
  vpc_cidr_block = var.vpc_cidr_block
  domain         = var.domain
  cluster_name   = var.cluster_name
  environment	= var.environment
}

module "services" {
  source                    = "../modules/services/"
  cluster_name              = var.cluster_name
  rds_password              = var.rds_password
  vpc_cidr_block           = var.vpc_cidr_block
  vpc_id                    = module.network.vpc_id
  aws_access_key            = var.aws_access_key
  aws_secret_key            = var.aws_secret_key
  aws_region                = var.aws_region
  es_domain					= var.es_domain
  domain                    = var.domain
  kops_state_bucket_name = "${var.environment}-kops-state"
  environment	= var.environment
  internet_gateway_id = module.network.internet_gateway_id
  aws_account_id            = var.aws_account_id
}




