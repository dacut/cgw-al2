resource "aws_vpc" "source" {
    cidr_block = "${var.source_vpc_cidr}"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "VPN Test Source"
    }
}

resource "aws_subnet" "source_a" {
    vpc_id = "${aws_vpc.source.id}"
    cidr_block = "${cidrsubnet(aws_vpc.source.cidr_block, 4, 0)}"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.source.ipv6_cidr_block, 8, 0)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.source.id}"
    tags = {
        Name = "VPN Test Source A"
    }
}

resource "aws_subnet" "source_b" {
    vpc_id = "${aws_vpc.source.id}"
    cidr_block = "${cidrsubnet(aws_vpc.source.cidr_block, 4, 1)}"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
    ipv6_cidr_block = "${cidrsubnet(aws_vpc.source.ipv6_cidr_block, 8, 1)}"
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    vpc_id = "${aws_vpc.source.id}"
    tags = {
        Name = "VPN Test Source B"
    }
}

resource "aws_internet_gateway" "source" {
    vpc_id = "${aws_vpc.source.id}"
    tags = {
        Name = "VPN Test Source"
    }
}

resource "aws_route" "source_egress_v4" {
    route_table_id = "${aws_vpc.source.default_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.source.id}"
}

resource "aws_route" "source_egress_v6" {
    route_table_id = "${aws_vpc.source.default_route_table_id}"
    destination_ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.source.id}"
}

resource "aws_route" "source_to_target" {
    route_table_id = "${aws_vpc.source.default_route_table_id}"
    destination_cidr_block = "${var.target_vpc_cidr}"
    network_interface_id = "${aws_network_interface.cgw.id}"
}

resource "aws_security_group" "source_debugging" {
    name = "VPN Test Debugging"
    description = "VPN Test Debugging -- allow SSH, ICMP"
    vpc_id = "${aws_vpc.source.id}"

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

resource "aws_security_group" "source_vpn" {
    name = "VPN"
    description = "VPN -- allow IPSec"
    vpc_id = "${aws_vpc.source.id}"

    ingress {
        protocol = "50"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "IPSec ESP"
    }

    ingress {
        protocol = "51"
        from_port = 0
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "IPSec AH"
    }

    ingress {
        protocol = "udp"
        from_port = 500
        to_port = 500
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "IPSec IKE"
    }

    ingress {
        protocol = "udp"
        from_port = 4500
        to_port = 4500
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        description = "IPSec IKE NAT"
    }
}

resource "aws_network_interface" "cgw" {
    security_groups = ["${aws_security_group.source_debugging.id}", "${aws_security_group.source_vpn.id}"]
    source_dest_check = false
    subnet_id = "${aws_subnet.source_a.id}"
}

resource "aws_eip" "cgw" {
    vpc = true
    tags = {
        Name = "VPN CGW Elastic IP"
    }
}

resource "aws_eip_association" "cgw" {
    allocation_id = "${aws_eip.cgw.id}"
    network_interface_id = "${aws_network_interface.cgw.id}"
}

resource "aws_instance" "source_ping" {
    ami = "${data.aws_ami.amzn2.id}"
    instance_type = "${var.source_ping_instance_type}"
    key_name = "${var.keypair}"
    monitoring = true
    vpc_security_group_ids = ["${aws_security_group.source_debugging.id}"]
    subnet_id = "${aws_subnet.source_a.id}"
    associate_public_ip_address = true
    ipv6_address_count = 1
    tags = {
        Name = "VPN Test Source"
    }
    user_data = "${file("${path.module}/instance_init.sh")}"
    volume_tags = {
        Name = "VPN Test Source"
    }
    root_block_device = {
        volume_type = "gp2"
        volume_size = 20
        delete_on_termination = true
    }
}

resource "aws_iam_role" "cgw" {
    name_prefix = "VPN-CGW-"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
    }
}
EOF
}

resource "aws_iam_role_policy" "cgw" {
    name_prefix = "Describe-VPN-"
    role = "${aws_iam_role.cgw.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": "ec2:DescribeVpnConnections",
        "Effect": "Allow",
        "Resource": "*"
    }
}
EOF
}

resource "aws_iam_instance_profile" "cgw" {
    name_prefix = "VPN-CGW-"
    role = "${aws_iam_role.cgw.id}"
}

resource "aws_instance" "cgw" {
    ami = "${data.aws_ami.amzn2.id}"
    iam_instance_profile = "${aws_iam_instance_profile.cgw.id}"
    instance_type = "${var.cgw_instance_type}"
    key_name = "${var.keypair}"
    network_interface {
        device_index = 0
        network_interface_id = "${aws_network_interface.cgw.id}"
        delete_on_termination = false
    }
    tags = {
        Name = "VPN CGW"
    }
    volume_tags = {
        Name = "VPN CGW"
    }
    root_block_device = {
        volume_type = "gp2"
        volume_size = 20
        delete_on_termination = true
    }
    user_data = <<UDEOF
${file("${path.module}/instance_init.sh")}
cat > /etc/sysconfig/network-scripts/ifup-awsvpn <<".EOF"
${file("${path.module}/ifup-awsvpn")}
.EOF
cat > /etc/sysconfig/network-scripts/ifdown-awsvpn <<".EOF"
${file("${path.module}/ifdown-awsvpn")}
.EOF
REGION="${var.region}"
VPN_ID="${aws_vpn_connection.source_target.id}"
TARGET_VPC_CIDR="${var.target_vpc_cidr}"
${file("${path.module}/cgw_init.sh")}
UDEOF
}

output "source_ping_ip_external" {
    value = "${aws_instance.source_ping.public_ip}"
}

output "source_ping_ip_internal" {
    value = "${aws_instance.source_ping.private_ip}"
}

output "cgw_ip" {
    value = "${aws_eip.cgw.public_ip}"
}