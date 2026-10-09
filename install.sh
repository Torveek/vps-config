#!/usr/bin/env bash
# ==============================================================================
# install.sh - Ubuntu 22.04 / 24.04 VPS Server Configuration & Hardening
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config and modules
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config.env"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ui.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/user.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/ssh.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/zsh.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/neovim.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/lazydocker.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/caddy.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/firewall.sh"

# Ensure root privileges
require_root

# Detect OS details & CPU architecture
detect_system

# Bootstrap Charm's 'gum' first before displaying any interactive UI
bootstrap_gum

# Header
ui_header "Ubuntu VPS Server Installer" "Ubuntu ${UBUNTU_VERSION:-unknown} (${UBUNTU_CODENAME:-unknown}) - ${ARCH}"

# Checkbox choices definition
OPT_USER="1. Create New Sudo User"
OPT_SSH="2. Configure SSH Hardening (Port, SSH Keys, Disable Root & Passwords)"
OPT_ZSH="3. Install Zsh + Oh My Zsh (Plugins, Starship Prompt, Dotfiles & Shell)"
OPT_NVIM="4. Install Neovim & LazyVim Configuration"
OPT_DOCKER="5. Install Docker Engine & Docker Compose"
OPT_LAZYDOCKER="6. Install Lazydocker"
OPT_CADDY="7. Install Caddy Proxy Server"
OPT_FIREWALL="8. Configure UFW Firewall & Disable Ping (ICMP)"

ALL_OPTIONS=(
  "$OPT_USER"
  "$OPT_SSH"
  "$OPT_ZSH"
  "$OPT_NVIM"
  "$OPT_DOCKER"
  "$OPT_LAZYDOCKER"
  "$OPT_CADDY"
  "$OPT_FIREWALL"
)

# Join options with comma for preselected default in gum
ALL_OPTIONS_CSV="$(IFS=,; echo "${ALL_OPTIONS[*]}")"

echo -e "\033[1;36mSelect components to configure (Space to toggle, Enter to confirm):\033[0m\n"

SELECTED_ITEMS=""
if has_gum; then
  SELECTED_ITEMS="$(gum choose --no-limit \
    --header "Use [Space] to select/deselect components and [Enter] to proceed:" \
    --cursor "➜ " \
    --selected "$ALL_OPTIONS_CSV" \
    "${ALL_OPTIONS[@]}")"
else
  # ANSI Fallback menu
  echo "Interactive gum is not available. Defaulting to all components."
  SELECTED_ITEMS="${ALL_OPTIONS[*]}"
fi

if [[ -z "$SELECTED_ITEMS" ]]; then
  ui_warn "No components were selected. Exiting."
  exit 0
fi

has_selected() {
  local item="$1"
  grep -Fq "$item" <<< "$SELECTED_ITEMS"
}

# ------------------------------------------------------------------------------
# Execution Pipeline
# ------------------------------------------------------------------------------

# 1. User Setup
if has_selected "$OPT_USER"; then
  setup_user
else
  # If user creation was not selected, prompt for target non-root user or root
  if has_selected "$OPT_SSH" || has_selected "$OPT_ZSH" || has_selected "$OPT_NVIM" || has_selected "$OPT_DOCKER"; then
    select_target_user
  fi
fi

# 2. SSH Hardening
if has_selected "$OPT_SSH"; then
  setup_ssh
fi

# 3. Zsh + Oh My Zsh + Starship
if has_selected "$OPT_ZSH"; then
  setup_zsh
fi

# 4. Neovim + LazyVim
if has_selected "$OPT_NVIM"; then
  setup_neovim
fi

# 5. Docker & Compose
if has_selected "$OPT_DOCKER"; then
  setup_docker
fi

# 6. Lazydocker
if has_selected "$OPT_LAZYDOCKER"; then
  setup_lazydocker
fi

# 7. Caddy Web Server
if has_selected "$OPT_CADDY"; then
  setup_caddy
fi

# 8. Firewall & Disable Ping
if has_selected "$OPT_FIREWALL"; then
  setup_firewall
fi

# ------------------------------------------------------------------------------
# Final Summary & Instructions
# ------------------------------------------------------------------------------
SERVER_IP="$(detect_ipv4)"
FINAL_SSH_PORT="${CONFIGURED_SSH_PORT:-22}"
FINAL_USER="${TARGET_USER:-root}"

echo ""
if has_gum; then
  gum style \
    --border double \
    --border-foreground 48 \
    --padding "1 2" \
    --margin "1 0" \
    "$(gum style --bold --foreground 48 "✓ VPS Setup & Configuration Completed Successfully!")" \
    "" \
    "$(gum style --bold "Server IP: ") $SERVER_IP" \
    "$(gum style --bold "SSH Port:  ") $FINAL_SSH_PORT" \
    "$(gum style --bold "User:      ") $FINAL_USER" \
    "" \
    "$(gum style --bold --foreground 214 "Important SSH Command for Next Login:")" \
    "$(gum style --foreground 39 "ssh -p $FINAL_SSH_PORT $FINAL_USER@$SERVER_IP")" \
    "" \
    "$(gum style --foreground 196 --bold "! WARNING: DO NOT close this terminal session before testing login in a separate window !")"
else
  echo -e "\033[1;32m============================================================\033[0m"
  echo -e "\033[1;32m✓ VPS Setup & Configuration Completed Successfully!\033[0m"
  echo -e "  Server IP:  ${SERVER_IP}"
  echo -e "  SSH Port:   ${FINAL_SSH_PORT}"
  echo -e "  User:       ${FINAL_USER}"
  echo -e "\n\033[1;33m  Login Command:\033[0m"
  echo -e "\033[1;36m    ssh -p ${FINAL_SSH_PORT} ${FINAL_USER}@${SERVER_IP}\033[0m"
  echo -e "\n\033[1;31m! WARNING: DO NOT close this terminal before testing login in a separate window !\033[0m"
  echo -e "\033[1;32m============================================================\033[0m"
fi
