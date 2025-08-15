#!/bin/bash
set -euo pipefail
export NEEDRESTART_SUSPEND=1

init_system() {
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install micro nano certbot htop btop iftop bmon cron net-tools curl wget
    curl -fsSL https://get.docker.com | sh
    timedatectl set-timezone UTC
}

configure_sysctl() {
    sysctl_settings=(
        "net.core.default_qdisc=fq"
        "net.ipv4.tcp_congestion_control=bbr"
        "net.ipv6.conf.all.disable_ipv6=1"
        "net.ipv6.conf.default.disable_ipv6=1"
        "net.ipv6.conf.lo.disable_ipv6=1"
    )

    for line in "${sysctl_settings[@]}"; do
        grep -qxF "$line" /etc/sysctl.conf || echo "$line" >> /etc/sysctl.conf
    done

    sysctl -p
    sysctl --system
}

configure_ssh() {
    cat <<'EOF' > /etc/ssh/sshd_config
# --- Network Configuration ---
ListenAddress 0.0.0.0
Port 8080

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

    read -rp "Enter your public SSH key: " SSH_KEY
    if [ -n "$SSH_KEY" ]; then
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        echo "$SSH_KEY" > ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    fi
    systemctl restart ssh
}

configure_dns() {
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
}

configure_cron() {
    (crontab -l 2>/dev/null; echo "0 0 * * * /sbin/shutdown -r now") | crontab -
}

configure_ssl() {
    read -rp "Enter your email for Let's Encrypt: " CERT_EMAIL
    read -rp "Enter your domain name: " CERT_DOMAIN
    [ -n "$CERT_EMAIL" ] && [ -n "$CERT_DOMAIN" ] && certbot certonly --standalone --agree-tos -m "$CERT_EMAIL" -d "$CERT_DOMAIN" --non-interactive
}

configure_shell() {
    cat <<'EOF' > ~/.bashrc
# Exit if not interactive
[ -z "$PS1" ] && return
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

force_color_prompt=yes
if [ -n "$force_color_prompt" ] && [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
else
    color_prompt=
fi
if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
    xterm*|rxvt*) PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" ;;
esac

if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b ~/.dircolors 2>/dev/null || dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

[ -f ~/.bash_aliases ] && . ~/.bash_aliases
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF

    source ~/.bashrc
}

main() {
    init_system
    configure_sysctl
    configure_ssh
    configure_dns
    configure_cron
    configure_ssl
    configure_shell
}

main "$@"
