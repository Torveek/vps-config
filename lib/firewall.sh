#!/usr/bin/env bash
# ==============================================================================
# lib/firewall.sh - UFW firewall setup & ICMP ping disable
# ==============================================================================

disable_ping() {
  ui_step "Disabling Ping (ICMP echo requests)..."

  # Method 1: sysctl kernel configuration
  local sysctl_conf="/etc/sysctl.d/99-disable-ping.conf"
  backup_file "$sysctl_conf"

  cat > "$sysctl_conf" <<'EOF'
# Disable incoming ping responses (ICMP echo requests)
net.ipv4.icmp_echo_ignore_all = 1
net.ipv6.icmp.echo_ignore_all = 1
EOF

  sysctl --system >/dev/null 2>&1 || true

  # Method 2: UFW before.rules & before6.rules
  local ufw_before="/etc/ufw/before.rules"
  local ufw_before6="/etc/ufw/before6.rules"

  if [[ -f "$ufw_before" ]]; then
    backup_file "$ufw_before"
    if ! grep -q "# Block ICMP ping requests" "$ufw_before"; then
      sed -i '/^# ok icmp codes for INPUT/i # Block ICMP ping requests\n-A ufw-before-input -p icmp --icmp-type echo-request -j DROP\n' "$ufw_before"
    fi
  fi

  if [[ -f "$ufw_before6" ]]; then
    backup_file "$ufw_before6"
    if ! grep -q "# Block ICMPv6 ping requests" "$ufw_before6"; then
      sed -i '/^# ok icmp codes for INPUT/i # Block ICMPv6 ping requests\n-A ufw-before-input -p icmpv6 --icmpv6-type echo-request -j DROP\n' "$ufw_before6"
    fi
  fi

  ufw reload >/dev/null 2>&1 || true

  if sysctl net.ipv4.icmp_echo_ignore_all 2>/dev/null | grep -q "= 1"; then
    ui_success "ICMP ping echo requests disabled successfully."
  else
    ui_warn "ICMP echo ignore configuration applied, please verify after reboot."
  fi
}

setup_firewall() {
  ui_step "Configuring UFW Firewall"

  # 1. Install UFW
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ufw

  # 2. Default policies
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null

  # 3. Allow SSH Port
  local ssh_port="${CONFIGURED_SSH_PORT:-${DEFAULT_SSH_PORT:-2222}}"
  ui_info "Allowing SSH on port ${ssh_port}/tcp in UFW..."
  ufw allow "${ssh_port}/tcp" comment "SSH Port" >/dev/null

  # Also ensure port 22 is allowed if user hasn't changed it
  if [[ "$ssh_port" != "22" ]]; then
    # We leave port 22 open or close it? If SSH port changed and verified, we only open the new port!
    :
  fi

  # 4. Allow Web Ports if Caddy or Docker is selected
  ui_info "Allowing HTTP (80) and HTTPS (443) ports in UFW..."
  ufw allow 80/tcp comment "HTTP (Caddy/Web)" >/dev/null
  ufw allow 443/tcp comment "HTTPS (Caddy/Web)" >/dev/null

  # 5. Enable UFW
  ufw --force enable >/dev/null
  ui_success "UFW firewall enabled with secure defaults!"

  # 6. Apply ping disable
  disable_ping
}
