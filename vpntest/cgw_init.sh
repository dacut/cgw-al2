# Enable the Extra Packages for Enterprise Linux (EPEL) repository, where
# strongSwan resides.
amazon-linux-extras install -y epel
yum install -y strongswan iptables-services

# Configure system settings (sysctl)
cat >> /etc/sysctl.conf <<.EOF
# Allow port forwarding -- we're a router.
net.ipv4.ip_forward = 1

# Disable crypto transformations on the physical interface
net.ipv4.conf.eth0.disable_xfrm = 1

# Disables IPsec policy (SPD) on the physical interface
net.ipv4.conf.eth0.disable_policy = 1
.EOF

chmod 755 /etc/sysconfig/network-scripts/ifup-awsvpn
chmod 755 /etc/sysconfig/network-scripts/ifdown-awsvpn

#### VPN configuration

# Get VPN parameters
orig_umask=$(umask)
umask 077
aws --output text --region "$REGION" ec2 describe-vpn-connections \
  --vpn-connection-id "$VPN_ID" \
  --query 'VpnConnections[0].CustomerGatewayConfiguration' > /etc/$VPN_ID.xml
umask $orig_umask

local_ipv4=$(curl -s http://169.254.169.254/2018-09-24/meta-data/local-ipv4)

tun1_cgw_in_addr=$(xmllint --xpath '//customer_gateway[1]/tunnel_inside_address/ip_address/text()' /etc/$VPN_ID.xml)
tun2_cgw_in_addr=$(xmllint --xpath '//customer_gateway[2]/tunnel_inside_address/ip_address/text()' /etc/$VPN_ID.xml)

tun1_vgw_in_addr=$(xmllint --xpath '//vpn_gateway[1]/tunnel_inside_address/ip_address/text()' /etc/$VPN_ID.xml)
tun2_vgw_in_addr=$(xmllint --xpath '//vpn_gateway[2]/tunnel_inside_address/ip_address/text()' /etc/$VPN_ID.xml)
tun1_vgw_out_addr=$(xmllint --xpath '//vpn_gateway[1]/tunnel_outside_address/ip_address/text()' /etc/$VPN_ID.xml)
tun2_vgw_out_addr=$(xmllint --xpath '//vpn_gateway[2]/tunnel_outside_address/ip_address/text()' /etc/$VPN_ID.xml)

tun1_psk=$(xmllint --xpath '//ike[1]/pre_shared_key/text()' /etc/$VPN_ID.xml)
tun2_psk=$(xmllint --xpath '//ike[2]/pre_shared_key/text()' /etc/$VPN_ID.xml)

# Write strongSwan configuration files
cat > /etc/strongswan/${VPN_ID}.conf <<.EOF
conn awsvpn1.common
    auto = start
    left = $local_ipv4
    type = tunnel
    leftauth = psk
    rightauth = psk
    keyexchange = ikev2
    ike = aes256-sha256-modp2048
    ikelifetime = 8h
    esp = aes256-sha256-modp2048
    lifetime = 1h
    keyingtries = %forever
    leftsubnet = 0.0.0.0/0
    rightsubnet = $TARGET_VPC_CIDR
    dpddelay = 10s
    dpdtimeout = 30s
    dpdaction = restart

conn awsvpn1.1
    also = awsvpn1.common
    right = $tun1_vgw_out_addr
    mark = 101

conn awsvpn1.2
    also = awsvpn1.common
    right = $tun2_vgw_out_addr
    mark = 102
.EOF

cat > /etc/strongswan/ipsec.conf <<.EOF
config setup
    uniqueids = no

include vpn*.conf
.EOF

umask 077
cat > /etc/strongswan/${VPN_ID}.secrets <<.EOF
$local_ipv4 $tun1_vgw_out_addr : PSK "$tun1_psk"
$local_ipv4 $tun2_vgw_out_addr : PSK "$tun2_psk"
.EOF

cat >> /etc/strongswan/ipsec.secrets <<.EOF
include vpn*.secrets
.EOF

# Don't allow Charon to configure routes or manage virtual IP address on VTI
# devices. See https://wiki.strongswan.org/projects/strongswan/wiki/RouteBasedVPN
mv /etc/strongswan/strongswan.d/charon.conf /etc/strongswan/strongswan.d/charon.orig
sed -E \
    -e 's/\s*#?\s*install_routes\s*=.*/    install_routes = no/' \
    -e 's/\s*#?\s*install_virtual_ip\s*=.*/    install_virtual_ip = no/' \
    /etc/strongswan/strongswan.d/charon.orig > \
    /etc/strongswan/strongswan.d/charon.conf

# Enable strongSwan at boot time and now
systemctl enable strongswan
systemctl start strongswan

# Configure VTI adapters
cat >> /etc/sysconfig/network-scripts/ifcfg-awsvpn1.1 <<.EOF
DEVICE=awsvpn1.1
DEVICETYPE=awsvpn
TYPE=awsvpn
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
PEERDNS=no
OUTSIDE_SRC_IPV4=$local_ipv4
OUTSIDE_DST_IPV4=$tun1_vgw_out_addr
INSIDE_SRC_IPV4=$tun1_cgw_in_addr/30
INSIDE_DST_IPV4=$tun1_vgw_in_addr/30
MTU=1419
MARK=101
METRIC=100
.EOF

cat >> /etc/sysconfig/network-scripts/ifcfg-awsvpn1.2 <<.EOF
DEVICE=awsvpn1.2
DEVICETYPE=awsvpn
TYPE=awsvpn
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
PEERDNS=no
OUTSIDE_SRC_IPV4=$local_ipv4
OUTSIDE_DST_IPV4=$tun2_vgw_out_addr
INSIDE_SRC_IPV4=$tun2_cgw_in_addr/30
INSIDE_DST_IPV4=$tun2_vgw_in_addr/30
MTU=1419
MARK=102
METRIC=200
.EOF

cat >> /etc/sysconfig/network-scripts/route-awsvpn1.1 <<.EOF
$TARGET_VPC_CIDR dev awsvpn1.1 metric 100
.EOF

cat >> /etc/sysconfig/network-scripts/route-awsvpn1.2 <<.EOF
$TARGET_VPC_CIDR dev awsvpn1.2 metric 200
.EOF

# Disable IPSec SPD and allow asymmetric routing on the VTI adapters.
cat >> /etc/sysctl.conf <<.EOF
net.ipv4.conf.awsvpn1/1.disable_policy=1
net.ipv4.conf.awsvpn1/2.disable_policy=1
net.ipv4.conf.awsvpn1/1.rp_filter=2
net.ipv4.conf.awsvpn1/2.rp_filter=2
.EOF
sysctl -p

ifup awsvpn1.1
ifup awsvpn1.2
