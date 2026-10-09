#!/usr/bin/env bash
# ==============================================================================
# lib/caddy.sh - Caddy web server & reverse proxy installation
# ==============================================================================

setup_caddy() {
  ui_step "Caddy Web Server & Reverse Proxy Installation"

  # 1. Install prerequisites
  ui_info "Installing prerequisite packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl

  # 2. Add Caddy official repository and keyring
  ui_info "Adding Caddy official Cloudsmith repository..."
  curl -1sLf "${CADDY_GPG_URL}" | gpg --dearmor -o "${CADDY_KEYRING}" 2>/dev/null
  curl -1sLf "${CADDY_DEB_LIST_URL}" | tee "${CADDY_LIST}" > /dev/null

  # 3. Install Caddy
  ui_info "Installing Caddy package..."
  apt-get update -qq
  apt-get install -y -qq caddy

  # 4. Configure starter Caddyfile
  local caddyfile="/etc/caddy/Caddyfile"
  if [[ -f "$caddyfile" ]]; then
    backup_file "$caddyfile"
  fi

  cat > "$caddyfile" <<'EOF'
# ==============================================================================
# /etc/caddy/Caddyfile
# Documentation: https://caddyserver.com/docs/caddyfile
# ==============================================================================

# Default welcome page on port 80
:80 {
    respond "Caddy reverse proxy is running! Edit /etc/caddy/Caddyfile to configure domains."
}

# ------------------------------------------------------------------------------
# Example Reverse Proxy to a Docker container or local service:
# ------------------------------------------------------------------------------
# example.com {
#     reverse_proxy 127.0.0.1:3000
# }
#
# subdomain.example.com {
#     reverse_proxy 127.0.0.1:8080 {
#         header_up Host {upstream_hostport}
#     }
# }
EOF

  # 5. Enable and start Caddy systemd service
  systemctl enable --now caddy >/dev/null 2>&1 || true
  systemctl restart caddy >/dev/null 2>&1 || true

  # 6. Verification
  if command -v caddy >/dev/null 2>&1 && systemctl is-active --quiet caddy; then
    local c_ver
    c_ver="$(caddy version | head -n 1)"
    ui_success "Caddy installed and active: ${c_ver}"
  else
    ui_warn "Caddy is installed but systemd service may not be active yet."
  fi
}
