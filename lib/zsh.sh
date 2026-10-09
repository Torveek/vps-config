#!/usr/bin/env bash
# ==============================================================================
# lib/zsh.sh - Zsh, Oh My Zsh, custom plugins, Starship prompt, and dotfiles
# ==============================================================================

setup_zsh() {
  ui_step "Zsh + Oh My Zsh Environment Setup"

  select_target_user

  # 1. Install prerequisites
  ui_info "Installing zsh, git, and curl via apt..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq zsh git curl

  # 2. Install Oh My Zsh for target user
  local omz_dir="${TARGET_HOME}/.oh-my-zsh"
  if [[ ! -d "$omz_dir" ]]; then
    ui_info "Cloning Oh My Zsh to ${omz_dir}..."
    git clone --depth=1 "${OMZ_REPO}" "$omz_dir"
  else
    ui_info "Oh My Zsh is already present at ${omz_dir}."
  fi

  # 3. Install custom plugins
  local plugins_dir="${omz_dir}/custom/plugins"
  mkdir -p "$plugins_dir"

  for entry in "${ZSH_CUSTOM_PLUGINS[@]}"; do
    local pname="${entry%%:*}"
    local purl="${entry#*:}"
    local pdest="${plugins_dir}/${pname}"

    if [[ ! -d "$pdest" ]]; then
      ui_info "Cloning plugin: ${pname}..."
      git clone --depth=1 "$purl" "$pdest"
    else
      ui_info "Plugin ${pname} is already installed."
    fi
  done

  # 4. Install Starship prompt binary into /usr/local/bin
  if ! command -v starship >/dev/null 2>&1; then
    ui_info "Installing Starship prompt to /usr/local/bin..."
    curl -sS "${STARSHIP_INSTALLER_URL}" | sh -s -- --yes --bin-dir /usr/local/bin >/dev/null 2>&1 || true
    if command -v starship >/dev/null 2>&1; then
      ui_success "Starship prompt installed."
    else
      ui_warn "Could not install Starship prompt automatically."
    fi
  else
    ui_info "Starship prompt is already installed."
  fi

  # 5. Install Zoxide binary into /usr/local/bin
  if ! command -v zoxide >/dev/null 2>&1; then
    ui_info "Installing zoxide to /usr/local/bin..."
    curl -sSfL "${ZOXIDE_INSTALLER_URL}" | sh -s -- --bin-dir /usr/local/bin >/dev/null 2>&1 || true
    if command -v zoxide >/dev/null 2>&1; then
      ui_success "zoxide installed."
    else
      ui_warn "Could not install zoxide automatically."
    fi
  else
    ui_info "zoxide is already installed."
  fi

  # 6. Deploy Dotfiles
  ui_info "Deploying Zsh dotfiles and Starship config..."
  local home_dotfiles=(".zshrc" ".zsh_aliases" ".zshenv" ".zprofile")
  for f in "${home_dotfiles[@]}"; do
    if [[ -f "${DOTFILES_DIR}/home/${f}" ]]; then
      backup_file "${TARGET_HOME}/${f}"
      cp -f "${DOTFILES_DIR}/home/${f}" "${TARGET_HOME}/${f}"
    fi
  done

  mkdir -p "${TARGET_HOME}/.config"
  if [[ -f "${DOTFILES_DIR}/config/starship.toml" ]]; then
    backup_file "${TARGET_HOME}/.config/starship.toml"
    cp -f "${DOTFILES_DIR}/config/starship.toml" "${TARGET_HOME}/.config/starship.toml"
  fi

  # 7. Change default shell to zsh
  local zsh_bin
  zsh_bin="$(command -v zsh || echo "/usr/bin/zsh")"
  if [[ -x "$zsh_bin" ]]; then
    ui_info "Setting default shell for '$TARGET_USER' to ${zsh_bin}..."
    chsh -s "$zsh_bin" "$TARGET_USER" 2>/dev/null || usermod -s "$zsh_bin" "$TARGET_USER"
  fi

  # 8. Set correct ownership
  chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME"

  ui_success "Zsh + Oh My Zsh and dotfiles configured successfully for '$TARGET_USER'!"
}
