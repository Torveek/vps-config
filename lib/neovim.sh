#!/usr/bin/env bash
# ==============================================================================
# lib/neovim.sh - Modern Neovim (v0.10+) binary install & LazyVim config deployment
# ==============================================================================

setup_neovim() {
  ui_step "Neovim Installation & LazyVim Configuration"

  select_target_user

  # 1. Install prerequisites for Neovim, Treesitter & Telescope
  ui_info "Installing dependencies (build-essential, ripgrep, fd-find, git, curl, unzip)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq build-essential ripgrep fd-find git curl unzip tar

  # Symlink fdfind -> fd if necessary (Ubuntu names the binary fdfind)
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  # 2. Install modern Neovim binary
  # Ubuntu 22.04 APT provides Neovim 0.6.1 which is incompatible with LazyVim (requires >= 0.9.0).
  # Installing official prebuilt binary to /opt/nvim guarantees modern 0.10+ on all versions.
  ui_info "Installing Neovim ${NEOVIM_VERSION} (${ARCH_NVIM})..."

  local nvim_tar="nvim-${ARCH_NVIM}.tar.gz"
  local nvim_url="https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}/${nvim_tar}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if curl -sSL --fail -o "${tmp_dir}/${nvim_tar}" "$nvim_url"; then
    mkdir -p /opt
    rm -rf "${NEOVIM_INSTALL_DIR}"
    tar -C /opt -xzf "${tmp_dir}/${nvim_tar}"
    if [[ -d "/opt/nvim-${ARCH_NVIM}" ]]; then
      mv "/opt/nvim-${ARCH_NVIM}" "${NEOVIM_INSTALL_DIR}"
    fi
    ln -sf "${NEOVIM_INSTALL_DIR}/bin/nvim" /usr/local/bin/nvim
  else
    ui_warn "Failed to download specific version ${NEOVIM_VERSION}. Attempting latest release..."
    local latest_url="https://github.com/neovim/neovim/releases/latest/download/${nvim_tar}"
    if curl -sSL --fail -o "${tmp_dir}/${nvim_tar}" "$latest_url"; then
      mkdir -p /opt
      rm -rf "${NEOVIM_INSTALL_DIR}"
      tar -C /opt -xzf "${tmp_dir}/${nvim_tar}"
      if [[ -d "/opt/nvim-${ARCH_NVIM}" ]]; then
        mv "/opt/nvim-${ARCH_NVIM}" "${NEOVIM_INSTALL_DIR}"
      fi
      ln -sf "${NEOVIM_INSTALL_DIR}/bin/nvim" /usr/local/bin/nvim
    else
      ui_err "Could not download Neovim binary. Falling back to apt-get install neovim."
      apt-get install -y -qq neovim
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
