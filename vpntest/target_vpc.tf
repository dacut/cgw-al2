resource "aws_vpc" "target" {
    cidr_block = "${var.target_vpc_cidr}"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "VPN Test Target"
    }
}

resource "aws_subnet" "target_a" {
    vpc_id = "${aws_vpc.target.id}"
    cidr_block = "${cidrsubnet(aws_vpc.target.cidr_block, 4, 0)}"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.target.ipv6_cidr_block, 8, 0)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.target.id}"
    tags = {
        Name = "VPN Test Target A"
    }
}

resource "aws_subnet" "target_b" {
    vpc_id = "${aws_vpc.target.id}"
    cidr_block = "${cidrsubnet(aws_vpc.target.cidr_block, 4, 1)}"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.target.ipv6_cidr_block, 8, 1)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.target.id}"
    tags = {
        Name = "VPN Test Target B"
    }
}

resource "aws_internet_gateway" "target" {
    vpc_id = "${aws_vpc.target.id}"
    tags = {
        Name = "VPN Test Target"
    }
}

resource "aws_route" "target_egress_v4" {
    route_table_id = "${aws_vpc.target.default_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.target.id}"
}

resource "aws_route" "target_egress_v6" {
    route_table_id = "${aws_vpc.target.default_route_table_id}"
    destination_ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.target.id}"
}

resource "aws_route" "target_to_source_v4" {
    route_table_id = "${aws_vpc.target.default_route_table_id}"
    destination_cidr_block = "${var.source_vpc_cidr}"
    gateway_id = "${aws_vpn_gateway.target.id}"
}

resource "aws_route" "target_to_source_v6" {
    route_table_id = "${aws_vpc.target.default_route_table_id}"
    destination_ipv6_cidr_block = "${aws_vpc.source.ipv6_cidr_block}"
    gateway_id = "${aws_vpn_gateway.target.id}"
}

resource "aws_security_group" "target_debugging" {
    name = "VPN Test Debugging"
    description = "VPN Test Debugging -- allow SSH, ICMP"
    vpc_id = "${aws_vpc.target.id}"

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

resource "aws_vpn_gateway" "target" {
    vpc_id = "${aws_vpc.target.id}"
    tags = {
        Name = "VPN Test VGW"
    }
}

resource "aws_customer_gateway" "source" {
    ip_address = "${aws_eip.cgw.public_ip}"
    type = "ipsec.1"
    bgp_asn = 65000

    tags = {
        Name = "VPN Test CGW"
    }
}

resource "aws_vpn_connection" "source_target" {
    customer_gateway_id = "${aws_customer_gateway.source.id}"
    vpn_gateway_id = "${aws_vpn_gateway.target.id}"
    type = "ipsec.1"
    static_routes_only = true
    tags = {
        Name = "VPN Test"
    }
}

resource "aws_vpn_connection_route" "to_source" {
    vpn_connection_id = "${aws_vpn_connection.source_target.id}"
    destination_cidr_block = "${var.source_vpc_cidr}"
}

resource "aws_instance" "target_ping" {
    ami = "${data.aws_ami.amzn2.id}"
    instance_type = "${var.target_ping_instance_type}"
    key_name = "${var.keypair}"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.target_debugging.id}"]
    subnet_id = "${aws_subnet.target_a.id}"
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

output "vpn_id" {
    value = "${aws_vpn_connection.source_target.id}"
}

output "target_ping_ip_external" {
    value = "${aws_instance.target_ping.public_ip}"
}

output "target_ping_ip_internal" {
    value = "${aws_instance.target_ping.private_ip}"
}
