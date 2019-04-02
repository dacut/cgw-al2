variable "region" { default = "us-west-2" }
variable "target_vpc_cidr" { default = "10.0.0.0/16" }

provider "aws" {
    region = "${var.region}"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "target_vpc" {
    cidr_block = "${var.target_vpc_cidr}"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "VPN Test Target"
    }
}

resource "aws_subnet" "target_subnet_a" {
    vpc_id = "${aws_vpc.target_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.target_vpc.cidr_block, 4, 0)}"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.target_vpc.ipv6_cidr_block, 8, 0)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.target_vpc.id}"
    tags = {
        Name = "VPN Test Target A"
    }
}

resource "aws_subnet" "target_subnet_b" {
    vpc_id = "${aws_vpc.target_vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.target_vpc.cidr_block, 4, 1)}"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.target_vpc.ipv6_cidr_block, 8, 1)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.target_vpc.id}"
    tags = {
        Name = "VPN Test Target B"
    }
}