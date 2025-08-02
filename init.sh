#!/bin/bash

set -euo pipefail
export NEEDRESTART_SUSPEND=1

# --- Init ---
apt-get -y update
apt-get -y upgrade
apt-get -y install micro nano certbot htop btop iftop bmon cron net-tools curl wget
curl -fsSL https://get.docker.com | sh

timedatectl set-timezone UTC


# --- Kernel networking settings (BBR & disable IPv6) ---
cat <<'EOF' >> /etc/sysctl.conf
# BBR & disable IPv6
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF

sysctl -p
sysctl --system


# --- Replace SSH configuration completely ---
cat <<'EOF' > /etc/ssh/sshd_config
# --- Network Configuration ---
ListenAddress 0.0.0.0
Port 65000

# --- Cryptographic Hardening ---
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
KexAlgorithms curve25519-sha256,ecdh-sha2-nistp521
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# --- Authentication Settings ---
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM no

# --- SSH Session Behavior ---
X11Forwarding yes
PrintMotd no

# --- Environment Configuration ---
AcceptEnv LANG LC_*

# --- SFTP Subsystem ---
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

systemctl restart ssh


# --- Replace systemd-resolved configuration ---
cat <<'EOF' > /etc/systemd/resolved.conf
[Resolve]
DNS=1.1.1.1
FallbackDNS=9.9.9.9
LLMNR=no
MulticastDNS=no 
DNSSEC=yes
DNSOverTLS=yes
DNSStubListener=yes
Cache=no-negative
CacheFromLocalhost=no
ReadEtcHosts=yes
ResolveUnicastSingleLabel=no
StaleRetentionSec=0
EOF

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved
systemctl start systemd-resolved


(crontab -l 2>/dev/null; echo "0 0 * * * /sbin/shutdown -r now") | crontab -


mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICtnDore2jiTo0IJYhA+7v+8Kmq9kBdEj/6/dP7lEKIP" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys


echo '\n\n' >> ~/.bashrc
echo 'force_color_prompt=yes' >> ~/.bashrc
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
source ~/.bashrc
