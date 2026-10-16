#!/usr/bin/env bash
# ==============================================================================
# lib/neovim.sh - Modern Neovim (latest stable, v0.11+) binary install & LazyVim config deployment
# ==============================================================================

setup_neovim() {
  ui_step "Neovim Installation & LazyVim Configuration"

  select_target_user

  # 1. Remove outdated distro neovim packages if present (Ubuntu repos have outdated <0.11 versions)
  ui_info "Ensuring any conflicting or outdated apt Neovim packages are removed..."
  apt-get remove -y -qq neovim neovim-runtime 2>/dev/null || true

  # 2. Install prerequisites for Neovim, Treesitter & Telescope / Snacks
  ui_info "Installing dependencies (build-essential, ripgrep, fd-find, git, curl, unzip, fzf)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq build-essential ripgrep fd-find git curl unzip tar fzf

  # Symlink fdfind -> fd if necessary (Ubuntu names the binary fdfind)
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  # 3. Determine latest modern Neovim release (LazyVim requires >= 0.11.2)
  local nvim_target_ver="${NEOVIM_VERSION:-latest}"
  if [[ "$nvim_target_ver" == "latest" ]]; then
    ui_info "Checking latest stable Neovim release on GitHub..."
    local detected_ver
    detected_ver="$(curl -sSL -o /dev/null -w '%{url_effective}' https://github.com/neovim/neovim/releases/latest 2>/dev/null | awk -F'/tag/' '{print $2}')"
    if [[ -n "$detected_ver" ]]; then
      nvim_target_ver="$detected_ver"
    else
      nvim_target_ver="${NEOVIM_FALLBACK_VERSION:-v0.12.6}"
    fi
  fi

  ui_info "Installing Neovim ${nvim_target_ver} (${ARCH_NVIM})..."

  local nvim_tar="nvim-${ARCH_NVIM}.tar.gz"
  local nvim_url="https://github.com/neovim/neovim/releases/download/${nvim_target_ver}/${nvim_tar}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  local download_success=false
  if curl -sSL --fail -o "${tmp_dir}/${nvim_tar}" "$nvim_url"; then
    download_success=true
  else
    ui_warn "Failed to download ${nvim_target_ver}. Trying direct latest release download..."
    local latest_url="https://github.com/neovim/neovim/releases/latest/download/${nvim_tar}"
    if curl -sSL --fail -o "${tmp_dir}/${nvim_tar}" "$latest_url"; then
      download_success=true
    fi
  fi

  if [[ "$download_success" == "true" ]]; then
    mkdir -p "${NEOVIM_INSTALL_DIR}"
    rm -rf "${NEOVIM_INSTALL_DIR:?}"/*
    tar -C "${NEOVIM_INSTALL_DIR}" --strip-components=1 -xzf "${tmp_dir}/${nvim_tar}"

    # Symlink to both /usr/local/bin and /usr/bin to guarantee precedence across all PATH environments
    ln -sf "${NEOVIM_INSTALL_DIR}/bin/nvim" /usr/local/bin/nvim
    ln -sf "${NEOVIM_INSTALL_DIR}/bin/nvim" /usr/bin/nvim
  else
    ui_warn "Tarball download failed. Attempting standalone AppImage binary..."
    local appimage_url="https://github.com/neovim/neovim/releases/latest/download/nvim-${ARCH_NVIM}.appimage"
    if curl -sSL --fail -o /usr/local/bin/nvim "$appimage_url"; then
      chmod +x /usr/local/bin/nvim
      ln -sf /usr/local/bin/nvim /usr/bin/nvim
    else
      ui_err "Could not download modern Neovim binary. Note: apt package is outdated and unsupported by LazyVim."
      rm -rf "$tmp_dir"
      return 1
    fi
  fi
  rm -rf "$tmp_dir"

  if command -v nvim >/dev/null 2>&1; then
    local nvim_ver
    nvim_ver="$(nvim --version | head -n 1)"
    ui_success "Neovim installed successfully: ${nvim_ver}"
  else
    ui_err "Neovim installation could not be verified."
    return 1
  fi

  # 3. Deploy LazyVim configuration from dotfiles
  local nvim_config_dir="${TARGET_HOME}/.config/nvim"
  ui_info "Deploying LazyVim configuration to ${nvim_config_dir}..."

  if [[ -d "${DOTFILES_DIR}/config/nvim" ]]; then
    backup_file "$nvim_config_dir"
    mkdir -p "$nvim_config_dir"
    cp -a "${DOTFILES_DIR}/config/nvim/." "${nvim_config_dir}/"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config"
    ui_success "LazyVim configuration deployed for '${TARGET_USER}'."
  else
    ui_warn "Dotfiles nvim directory not found at ${DOTFILES_DIR}/config/nvim."
  fi
}
