#!/bin/bash -x
yum update -y
yum install -y ltrace python3 strace tcpdump trousers util-linux-user zsh
chsh -s /bin/zsh
chsh -s /bin/zsh ec2-user
if [[ ! -d /home/ec2-user ]]; then mkdir -p /home/ec2-user; chown 1000:1000 /home/ec2-user; fi
cat > /home/ec2-user/.zshrc <<.EOF
autoload -Uz compinit
compinit
PROMPT="%B%! %n@%m %3/%#%b "
export LESS=-XR
.EOF

cp /home/ec2-user/.zshrc /root/.zshrc
chown ec2-user:ec2-user /home/ec2-user/.zshrc || chown 1000:1000 /home/ec2-user/.zshrc
chown root:root /root/.zshrc
