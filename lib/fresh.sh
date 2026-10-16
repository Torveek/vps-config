#!/usr/bin/env bash
# ==============================================================================
# lib/fresh.sh - Fresh terminal text editor installation
# ==============================================================================

setup_fresh() {
  ui_step "Fresh Text Editor Installation"

  ui_info "Checking latest release of Fresh text editor..."
  local fresh_ver
  fresh_ver="$(curl -sSL -o /dev/null -w '%{url_effective}' https://github.com/sinelaw/fresh/releases/latest 2>/dev/null | awk -F'/tag/' '{print $2}')"
  fresh_ver="${fresh_ver:-${FRESH_DEFAULT_VERSION:-v0.5.3}}"
  local ver_clean="${fresh_ver#v}"

  ui_info "Installing Fresh text editor ${fresh_ver} (${ARCH_DEB})..."

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local tmp_deb="${tmp_dir}/fresh-editor.deb"
  local deb_url="https://github.com/sinelaw/fresh/releases/download/${fresh_ver}/fresh-editor_${ver_clean}-1_${ARCH_DEB}.deb"

  # Method 1: Install official prebuilt .deb package from GitHub release
  if curl -sSL --fail -o "$tmp_deb" "$deb_url"; then
    ui_info "Installing package via dpkg..."
    export DEBIAN_FRONTEND=noninteractive
    dpkg -i "$tmp_deb" >/dev/null 2>&1 || apt-get install -f -y -qq >/dev/null 2>&1 || true
  fi

  # Method 2: Official installer script fallback
  if ! command -v fresh >/dev/null 2>&1; then
    ui_warn "Direct .deb installation failed. Trying official universal installer script..."
    export FRESH_NO_DESKTOP=1
    curl -fsSL "${FRESH_INSTALLER_URL}" | sh -s -- --method=deb >/dev/null 2>&1 || true
  fi

  # Method 3: Standalone static musl tarball fallback
  if ! command -v fresh >/dev/null 2>&1; then
    ui_warn "Debian package install failed. Falling back to static musl binary..."
    local musl_arch="x86_64"
    [[ "${ARCH:-}" == "arm64" ]] && musl_arch="aarch64"
    local tar_url="https://github.com/sinelaw/fresh/releases/download/${fresh_ver}/fresh-editor-${musl_arch}-unknown-linux-musl.tar.gz"
    local tar_file="${tmp_dir}/fresh.tar.gz"

    if curl -sSL --fail -o "$tar_file" "$tar_url"; then
      tar -xzf "$tar_file" -C "$tmp_dir"
      local bin_found
      bin_found="$(find "$tmp_dir" -type f -name "fresh*" -perm -111 2>/dev/null | head -n 1)"
      if [[ -n "$bin_found" ]]; then
        install -m 0755 "$bin_found" /usr/local/bin/fresh
      fi
    fi
  fi
  rm -rf "$tmp_dir"

  # Ensure symlinks exist in /usr/local/bin for both 'fresh' and 'fresh-editor'
  local bin_loc
  bin_loc="$(command -v fresh 2>/dev/null || echo "")"
  if [[ -n "$bin_loc" ]]; then
    ln -sf "$bin_loc" /usr/local/bin/fresh 2>/dev/null || true
    ln -sf "$bin_loc" /usr/local/bin/fresh-editor 2>/dev/null || true
  fi

  if command -v fresh >/dev/null 2>&1; then
    local fresh_ver_out
    fresh_ver_out="$(fresh --version 2>/dev/null || echo "installed")"
    ui_success "Fresh text editor installed successfully: ${fresh_ver_out}"
  else
    ui_err "Could not install Fresh text editor."
    return 1
  fi
}
