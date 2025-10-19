#!/bin/bash
set -euo pipefail
export NEEDRESTART_SUSPEND=1

init_system() {
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install bc bmon btop curl cron dnsutils htop iftop jq micro nano net-tools util-linux uuid-runtime wget certbot
    curl -fsSL https://get.docker.com | sh
    timedatectl set-timezone UTC
}

configure_sysctl() {
    cat > /etc/sysctl.conf <<'EOF'
# Network Performance
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# IPv4 Security
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.tcp_syncookies=1
net.ipv4.ip_forward=0

# IPv6 Disabling
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
    sysctl --system
}

configure_ssh() {
    local ssh_key="$1"

    cat > /etc/ssh/sshd_config <<'EOF'
# Supported HostKey algorithms by order of preference.
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

# Network
ListenAddress 0.0.0.0
Port 8080

# Cryptographic
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

# Authentication
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitRootLogin prohibit-password
UsePAM no

# Session
X11Forwarding yes
PrintMotd no

# Environment
AcceptEnv LANG LC_*

# SFTP
Subsystem sftp  /usr/lib/ssh/sftp-server -f AUTHPRIV -l INFO    # Enable SFTP subsystem
EOF

    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    [ -n "$ssh_key" ] && echo "$ssh_key" > ~/.ssh/authorized_keys || touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    systemctl restart ssh
}

configure_dns() {
    cat > /etc/systemd/resolved.conf <<'EOF'
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
    systemctl enable --now systemd-resolved
}

configure_cron() {
    (crontab -l 2>/dev/null; echo "0 0 * * * /sbin/shutdown -r now") | crontab -
}

configure_ssl() {
    local cert_email="$1"
    local cert_domain="$2"

    if [ -n "$cert_email" ] && [ -n "$cert_domain" ]; then
        certbot certonly --standalone --agree-tos -m "$cert_email" -d "$cert_domain" --non-interactive
    fi
}

configure_shell() {
    cat > ~/.bashrc <<'EOF'
# ~/.bashrc

# ===============================
# 1. Interactive check
# ===============================
[ -z "$PS1" ] && return

# ===============================
# 2. History
# ===============================
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=5000
HISTFILESIZE=10000
HISTTIMEFORMAT="%F %T "
shopt -s cmdhist histreedit histverify

# ===============================
# 3. Prompt
# ===============================
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    base_PS1="\[\033[35m\]\$(/bin/date '+%Y-%m-%d %H:%M:%S') \[\033[1;31m\]\u@\h \[\033[1;34m\]\$(pwd)\[\033[0m\] -> "
else
    base_PS1="\$(/bin/date '+%Y-%m-%d %H:%M:%S') \u@\h \$(pwd) -> "
fi
PROMPT_COMMAND='ret=$?; PS1="$( [ $ret -ne 0 ] && printf "\[\033[0;31m\](%d)\[\033[0m\] " $ret)$base_PS1"'

# ===============================
# 4. Colors
# ===============================
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b ~/.dircolors 2>/dev/null || dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ===============================
# 5. Aliases
# ===============================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ll='ls -alF --group-directories-first'
alias ducks='du -hs * | sort -hr'
alias reload='source ~/.bashrc'

# ===============================
# 6. Variables
# ===============================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LESS='-R'

# ===============================
# 7. Completion
# ===============================
[[ $PS1 && -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

# ===============================
# 8. Extra settings
# ===============================
shopt -s dotglob globstar
EOF
}

# all root
main() {
    local ssh_key="${1:-${SSH_KEY:-}}"
    local cert_email="${2:-${CERT_EMAIL:-}}"
    local cert_domain="${3:-${CERT_DOMAIN:-}}"

    init_system
    configure_sysctl
    configure_ssh "$ssh_key"
    configure_dns
    configure_cron
    configure_ssl "$cert_email" "$cert_domain"
    configure_shell
}

main "$@"
