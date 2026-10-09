#!/usr/bin/env bash
# ==============================================================================
# lib/ssh.sh - SSH port change, key installation, hardening, Ubuntu 24.04 fix
# ==============================================================================

comment_conflicting_sshd_includes() {
  local d="/etc/ssh/sshd_config.d"
  [[ -d "$d" ]] || return 0
  for f in "$d"/*.conf; do
    [[ -e "$f" ]] || continue
    backup_file "$f"
    sed -i -E \
      's/^[[:space:]]*#?[[:space:]]*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|KbdInteractiveAuthentication|ChallengeResponseAuthentication)[[:space:]].*$/# disabled by installer: &/I' \
      "$f"
  done
}

apply_sshd_directive() {
  local key="$1"
  local val="$2"
  if grep -qiE "^[#[:space:]]*${key}[[:space:]]" /etc/ssh/sshd_config; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]].*$|${key} ${val}|I" /etc/ssh/sshd_config
  else
    echo "${key} ${val}" >> /etc/ssh/sshd_config
  fi
}

validate_ssh_key() {
  local key="$1"
  if [[ "$key" =~ ^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+[A-Za-z0-9+/=]+ ]]; then
    return 0
  fi
  return 1
}

setup_ssh() {
  ui_step "SSH Hardening & Security Configuration"

  select_target_user

  # 1. Prompt for SSH Port
  local ssh_port=""
  while true; do
    ssh_port="$(ui_input "Enter new SSH Port" "${DEFAULT_SSH_PORT:-2222}" "Recommended: 1024-65535")"
    ssh_port="$(echo "$ssh_port" | xargs)"

    if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [[ "$ssh_port" -ge 22 ]] && [[ "$ssh_port" -le 65535 ]]; then
      break
    else
      ui_err "Invalid port number. Must be an integer between 22 and 65535."
    fi
  done
  CONFIGURED_SSH_PORT="$ssh_port"
  export CONFIGURED_SSH_PORT

  # 2. Prompt for SSH Public Key
  local ssh_pubkey=""
  ui_info "Please provide your SSH public key for user '$TARGET_USER'."
  
  while true; do
    if has_gum; then
      echo "$(gum style --italic --foreground 245 "Paste your public key (ssh-ed25519, ssh-rsa, etc.) and press Enter:")"
      ssh_pubkey="$(gum input --placeholder "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host")"
    else
      read -r -p "Paste SSH public key: " ssh_pubkey
    fi
    ssh_pubkey="$(echo "$ssh_pubkey" | xargs)"

    if validate_ssh_key "$ssh_pubkey"; then
      ui_success "Valid SSH public key detected."
      break
    else
      ui_err "Invalid SSH public key format."
      if [[ -f "/root/.ssh/authorized_keys" ]] && grep -qE '^ssh-' /root/.ssh/authorized_keys; then
        if ui_confirm "Found existing key in /root/.ssh/authorized_keys. Import that key instead?" "yes"; then
          ssh_pubkey="$(head -n 1 /root/.ssh/authorized_keys)"
          if validate_ssh_key "$ssh_pubkey"; then
            ui_success "Imported valid SSH key from root."
            break
          fi
        fi
      fi
      if ! ui_confirm "Would you like to try entering the SSH key again?" "yes"; then
        ui_warn "SSH key setup canceled. Skipping SSH hardening to prevent lockout!"
        return 1
      fi
    fi
  done

  # 3. Install SSH Key to Target User's authorized_keys
  local user_ssh_dir="${TARGET_HOME}/.ssh"
  local auth_keys="${user_ssh_dir}/authorized_keys"

  mkdir -p "$user_ssh_dir"
  chmod 700 "$user_ssh_dir"

  # Avoid duplicating key if already present
  if [[ -f "$auth_keys" ]] && grep -Fq "$ssh_pubkey" "$auth_keys"; then
    ui_info "SSH key is already present in ${auth_keys}."
  else
    echo "$ssh_pubkey" >> "$auth_keys"
    ui_success "SSH key added to ${auth_keys}."
  fi

  chmod 600 "$auth_keys"
  chown -R "${TARGET_USER}:${TARGET_USER}" "$user_ssh_dir"

  # 4. Apply SSH Server Configuration Hardening
  ui_info "Backing up and hardening /etc/ssh/sshd_config..."
  comment_conflicting_sshd_includes
  backup_file "/etc/ssh/sshd_config"

  apply_sshd_directive "Port" "$ssh_port"
  apply_sshd_directive "PubkeyAuthentication" "yes"
  apply_sshd_directive "PasswordAuthentication" "no"
  apply_sshd_directive "PermitRootLogin" "no"
  apply_sshd_directive "KbdInteractiveAuthentication" "no"
  apply_sshd_directive "ChallengeResponseAuthentication" "no"

  # 5. Ubuntu 24.04 Systemd Socket Activation Workaround
  # In Ubuntu 24.04, ssh.socket manages port 22 by default and ignores sshd_config.
  # We disable ssh.socket and switch to classic standalone ssh.service.
  if [[ "${UBUNTU_VERSION:-}" == "24.04" ]] || systemctl is-active --quiet ssh.socket 2>/dev/null; then
    ui_info "Ubuntu 24.04 detected: Switching from ssh.socket activation to ssh.service..."
    systemctl disable --now ssh.socket 2>/dev/null || true
    systemctl enable --now ssh.service 2>/dev/null || true
  fi

  # 6. Syntax check before restart
  if ! sshd -t; then
    ui_err "sshd configuration test failed! Restoring backup..."
    local latest_bak
    latest_bak="$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | head -n 1)"
    if [[ -n "$latest_bak" ]]; then
      cp -a "$latest_bak" /etc/ssh/sshd_config
      ui_info "Restored /etc/ssh/sshd_config from backup."
    fi
    return 1
  fi

  # 7. Restart SSH service safely
  ui_info "Restarting SSH service..."
  if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    ui_success "SSH service restarted successfully on port ${ssh_port}!"
  else
    ui_err "Failed to restart SSH service. Please check 'journalctl -xeu ssh'."
    return 1
  fi

  local ip
  ip="$(detect_ipv4)"
  ui_warn "CRITICAL: Do NOT close this terminal session!"
  ui_warn "Open a NEW terminal on your local machine and verify login:"
  echo -e "\033[1;36m    ssh -p ${ssh_port} ${TARGET_USER}@${ip}\033[0m\n"
}
