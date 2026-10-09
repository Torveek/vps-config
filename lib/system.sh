#!/usr/bin/env bash
# ==============================================================================
# lib/system.sh - OS detection, architecture, gum bootstrapping, and helpers
# ==============================================================================

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    ui_err "This installer must be run as root. Please run with sudo: sudo ./install.sh"
    exit 1
  fi
}

detect_system() {
  if [[ ! -f /etc/os-release ]]; then
    ui_err "Cannot detect OS: /etc/os-release not found."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    ui_warn "Detected OS is '${ID:-unknown}' (${PRETTY_NAME:-unknown}), but this installer is optimized for Ubuntu."
    if ! ui_confirm "Do you wish to proceed anyway?" "no"; then
      exit 1
    fi
  fi

  UBUNTU_VERSION="${VERSION_ID:-}"
  UBUNTU_CODENAME="${VERSION_CODENAME:-}"

  if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
    ui_info "Detected Ubuntu 22.04 LTS (Jammy Jellyfish)"
  elif [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    ui_info "Detected Ubuntu 24.04 LTS (Noble Numbat)"
  else
    ui_warn "Detected Ubuntu ${UBUNTU_VERSION:-unknown}. (Recommended: 22.04 or 24.04)"
  fi

  # Architecture detection
  local raw_arch
  raw_arch="$(uname -m)"
  case "$raw_arch" in
    x86_64)
      ARCH="x86_64"
      ARCH_DEB="amd64"
      ARCH_NVIM="linux-x86_64"
      ;;
    aarch64|arm64)
      ARCH="arm64"
      ARCH_DEB="arm64"
      ARCH_NVIM="linux-arm64"
      ;;
    *)
      ui_err "Unsupported CPU architecture: $raw_arch"
      exit 1
      ;;
  esac

  export UBUNTU_VERSION UBUNTU_CODENAME ARCH ARCH_DEB ARCH_NVIM
}

bootstrap_gum() {
  if command -v gum >/dev/null 2>&1; then
    return 0
  fi

  echo -e "\033[1;34m[INFO]\033[0m Charm 'gum' not found. Installing gum..."

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null 2>&1 || true
  apt-get install -y -qq curl gnupg ca-certificates >/dev/null 2>&1 || true

  # Method 1: Official Charm APT repository
  mkdir -p /etc/apt/keyrings
  if curl -fsSL "${CHARM_GPG_URL}" | gpg --dearmor -o "${CHARM_KEYRING}" 2>/dev/null; then
    echo "deb [signed-by=${CHARM_KEYRING}] ${CHARM_REPO_URL} * *" > "${CHARM_LIST}"
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get install -y -qq gum >/dev/null 2>&1 || true
  fi

  # Method 2: Fallback to standalone binary from GitHub releases
  if ! command -v gum >/dev/null 2>&1; then
    echo -e "\033[1;33m[WARN]\033[0m APT install of gum failed. Falling back to GitHub release binary..."
    local gum_arch="x86_64"
    [[ "$ARCH" == "arm64" ]] && gum_arch="arm64"

    local gum_tmp
    gum_tmp="$(mktemp -d)"
    local gum_tar="${gum_tmp}/gum.tar.gz"
    
    local gum_ver="0.14.5"
    local gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_ver}/gum_${gum_ver}_Linux_${gum_arch}.tar.gz"

    if curl -sSL -o "$gum_tar" "$gum_url"; then
      tar -xzf "$gum_tar" -C "$gum_tmp"
      find "$gum_tmp" -type f -name gum -exec cp {} /usr/local/bin/gum \;
      chmod +x /usr/local/bin/gum
    fi
    rm -rf "$gum_tmp"
  fi

  if command -v gum >/dev/null 2>&1; then
    echo -e "\033[1;32m[SUCCESS]\033[0m Charm 'gum' ready!"
  else
    echo -e "\033[1;33m[WARN]\033[0m Could not install 'gum'. Falling back to standard CLI prompts."
  fi
}

detect_ipv4() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "$ip" ]] || [[ "$ip" =~ ^127\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$ip" =~ ^10\. ]]; then
    local public_ip
    public_ip="$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || curl -s --max-time 3 https://ifconfig.me 2>/dev/null || true)"
    if [[ -n "$public_ip" ]]; then
      ip="$public_ip"
    fi
  fi
  echo "${ip:-<SERVER_IP>}"
}

backup_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local bak="${f}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$f" "$bak"
}
