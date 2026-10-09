#!/usr/bin/env bash
# ==============================================================================
# lib/user.sh - Sudo user creation & management
# ==============================================================================

setup_user() {
  ui_step "User Configuration: Add New Sudo User"

  local user_name=""
  while true; do
    user_name="$(ui_input "Enter new username" "" "e.g. dev, deploy, admin")"
    user_name="$(echo "$user_name" | xargs)"

    if [[ -z "$user_name" ]]; then
      ui_err "Username cannot be empty."
      continue
    fi

    if [[ "$user_name" == "root" ]]; then
      ui_err "Username cannot be 'root'."
      continue
    fi

    # POSIX / Linux username convention
    if ! [[ "$user_name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
      ui_err "Invalid username format. Must start with a letter/underscore and contain only lowercase letters, numbers, hyphens, or underscores."
      continue
    fi

    break
  done

  local user_pass=""
  while true; do
    local pass1 pass2
    pass1="$(ui_password "Enter password for '$user_name'" "Min 8 characters recommended")"
    if [[ -z "$pass1" ]]; then
      ui_err "Password cannot be empty."
      continue
    fi

    pass2="$(ui_password "Confirm password for '$user_name'" "Re-type password")"
    if [[ "$pass1" != "$pass2" ]]; then
      ui_err "Passwords do not match. Please try again."
      continue
    fi

    user_pass="$pass1"
    break
  done

  # Create or update user
  if id "$user_name" >/dev/null 2>&1; then
    ui_warn "User '$user_name' already exists."
    if ui_confirm "Update password and ensure sudo access for '$user_name'?" "yes"; then
      echo "${user_name}:${user_pass}" | chpasswd
      usermod -aG sudo "$user_name"
      ui_success "Updated password and sudo group for existing user '$user_name'."
    fi
  else
    useradd -m -s /bin/bash "$user_name"
    echo "${user_name}:${user_pass}" | chpasswd
    usermod -aG sudo "$user_name"
    ui_success "User '$user_name' created with home directory and added to 'sudo' group."
  fi

  TARGET_USER="$user_name"
  TARGET_HOME="/home/${user_name}"
  export TARGET_USER TARGET_HOME
}

select_target_user() {
  # If TARGET_USER is already set, keep it
  if [[ -n "${TARGET_USER:-}" ]]; then
    return 0
  fi

  # Find regular users with UID >= 1000 and home directory in /home
  local candidates=()
  while IFS=: read -r uname _ uid _ _ uhome _; do
    if [[ "$uid" -ge 1000 && "$uhome" =~ ^/home/ && -d "$uhome" && "$uname" != "nobody" ]]; then
      candidates+=("$uname")
    fi
  done < /etc/passwd

  if [[ ${#candidates[@]} -eq 1 ]]; then
    TARGET_USER="${candidates[0]}"
    TARGET_HOME="/home/${TARGET_USER}"
    ui_info "Using existing user '$TARGET_USER' for environment configuration."
  elif [[ ${#candidates[@]} -gt 1 ]]; then
    ui_info "Select existing user to configure:"
    if has_gum; then
      TARGET_USER="$(gum choose "${candidates[@]}")"
    else
      select u in "${candidates[@]}"; do
        TARGET_USER="$u"
        break
      done
    fi
    TARGET_HOME="/home/${TARGET_USER}"
    ui_info "Selected user '$TARGET_USER'."
  else
    ui_warn "No regular non-root user found. Defaulting to root."
    TARGET_USER="root"
    TARGET_HOME="/root"
  fi

  export TARGET_USER TARGET_HOME
}
