# add aws account, access key and secrets here
variable "aws_access_key" {
default= ""
}
variable "aws_secret_key" {
default= ""
}

variable "aws_region" {    
    default = "ap-southeast-2"
}

variable "aws_account_id" {    
    default = ""
}

variable "domain" {
	default="demo.local"
}
variable "cluster_name" {
default= "test.demo.local"
}


variable "environment" {
default="test"
}



# VPC_cidr_block 
variable "vpc_cidr_block" {
default= "10.0.0.0/21"
}
