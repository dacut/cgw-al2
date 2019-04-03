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

resource "aws_internet_gateway" "target_igw" {
    vpc_id = "${aws_vpc.target_vpc.id}"
    tags = {
        Name = "VPN Test Target"
    }
}

resource "aws_route" "target_egress_v4" {
    route_table_id = "${aws_vpc.target_vpc.default_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.target_igw.id}"
}

resource "aws_route" "target_egress_v6" {
    route_table_id = "${aws_vpc.target_vpc.default_route_table_id}"
    destination_ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.target_igw.id}"
}

resource "aws_security_group" "target_vpc_debugging_sg" {
    name = "VPN Test Debugging"
    description = "VPN Test Debugging -- allow SSH, ICMP"
    vpc_id = "${aws_vpc.target_vpc.id}"

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "SSH from anywhere"
    }

    ingress {
        protocol = "icmp"
        from_port = -1
        to_port = -1
        cidr_blocks = ["0.0.0.0/0"]
        description = "ICMPv4 from anywhere"
    }

    ingress {
        protocol = "icmpv6"
        from_port = -1
        to_port = -1
        ipv6_cidr_blocks = ["::/0"]
        description = "ICMPv6 from anywhere"
    }

    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "Egress anywhere"
    }
}
resource "aws_instance" "target_instance" {
    ami = "${data.aws_ami.amzn2.id}"
    instance_type = "${var.target_instance_type}"
    key_name = "${var.keypair}"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.target_vpc_debugging_sg.id}"]
    subnet_id = "${aws_subnet.target_subnet_a.id}"
    associate_public_ip_address = true
    ipv6_address_count = 1
    tags = {
        Name = "VPN Test Target"
    }
    user_data = "${file("${path.module}/instance_init.sh")}"
    volume_tags = {
        Name = "VPN Test Target"
    }
    root_block_device = {
        volume_type = "gp2"
        volume_size = 20
        delete_on_termination = true
    }
}