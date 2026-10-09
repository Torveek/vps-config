#!/usr/bin/env bash
# ==============================================================================
# lib/lazydocker.sh - Lazydocker terminal UI for Docker
# ==============================================================================

setup_lazydocker() {
  ui_step "Lazydocker Installation"

  ui_info "Installing lazydocker to /usr/local/bin..."

  # Install via official installer script
  if curl -fsSL "${LAZYDOCKER_INSTALLER_URL}" | DIR=/usr/local/bin bash >/dev/null 2>&1; then
    chmod +x /usr/local/bin/lazydocker 2>/dev/null || true
  fi

  # Fallback: direct GitHub release download if script failed
  if ! command -v lazydocker >/dev/null 2>&1; then
    ui_warn "Installer script failed. Trying direct GitHub release binary..."
    local lz_arch="x86_64"
    [[ "${ARCH:-}" == "arm64" ]] && lz_arch="arm64"
    
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local lz_tar="${tmp_dir}/lazydocker.tar.gz"
    local lz_url="https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_Linux_${lz_arch}.tar.gz"

    if curl -sSL -o "$lz_tar" "$lz_url"; then
      tar -xzf "$lz_tar" -C "$tmp_dir"
      if [[ -f "${tmp_dir}/lazydocker" ]]; then
        install -m 0755 "${tmp_dir}/lazydocker" /usr/local/bin/lazydocker
      fi
    fi
    rm -rf "$tmp_dir"
  fi

  if command -v lazydocker >/dev/null 2>&1; then
    local lz_ver
    lz_ver="$(lazydocker --version 2>/dev/null | head -n 1 || echo "installed")"
    ui_success "Lazydocker installed: ${lz_ver}"
  else
    ui_err "Could not install lazydocker."
    return 1
  fi
}
