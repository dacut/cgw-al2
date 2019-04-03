#!/bin/bash
yum update -y
yum install -y ltrace strace tcpdump util-linux-user zsh
chsh -s /bin/zsh
chsh -s /bin/zsh ec2-user
if [[ ! -d /home/ec2-user ]]; then mkdir -p /home/ec2-user; chown 1000:1000 /home/ec2-user; fi
echo 'export PROMPT="%B%! %n@%m %3/%#%b "' > /home/ec2-user/.zshrc
chown ec2-user:ec2-user /home/ec2-user/.zshrc || chown 1000:1000 /home/ec2-user/.zshrc
echo 'export PROMPT="%B%! %n@%m %3/%#%b "' > /root/.zshrc
