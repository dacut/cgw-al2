variable "region" { default = "us-west-2" }
variable "source_vpc_cidr" { default = "10.1.0.0/16" }
variable "target_vpc_cidr" { default = "10.0.0.0/16" }
variable "keypair" {}
variable "cgw_instance_type" { default = "t3.large" }
variable "source_ping_instance_type" { default = "t3.nano" }
variable "target_ping_instance_type" { default = "t3.nano" }

provider "aws" {
    region = "${var.region}"
}

data "aws_availability_zones" "available" {}
data "aws_ami" "amzn2" {
    most_recent = true
    filter {
        name = "architecture"
        values = ["x86_64"]
    }

    filter {
        name = "ena-support"
        values = ["true"]
    }

    filter {
        name = "name"
        values = ["amzn2-ami-hvm-2.0*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["045324592363", "137112412989"]
}
