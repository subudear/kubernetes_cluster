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
	default="k8s.local"
}
variable "cluster_name" {
default= "test.k8s.local"
}


variable "environment" {
default="test"
}



# VPC_cidr_block 
variable "vpc_cidr_block" {
default= "10.0.0.0/21"
}
