#!/usr/bin/env bash
# ==============================================================================
# lib/docker.sh - Docker CE, containerd, and Docker Compose plugin
# ==============================================================================

setup_docker() {
  ui_step "Docker & Docker Compose Installation"

  select_target_user

  # 1. Install prerequisites
  ui_info "Installing prerequisite packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

  # 2. Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f "${DOCKER_KEYRING}" ]]; then
    ui_info "Adding Docker official GPG key..."
    curl -fsSL "${DOCKER_GPG_URL}" | gpg --dearmor -o "${DOCKER_KEYRING}"
    chmod a+r "${DOCKER_KEYRING}"
  fi

  # 3. Add the Docker APT repository
  local codename="${UBUNTU_CODENAME}"
  if [[ -z "$codename" ]]; then
    codename="$(lsb_release -cs 2>/dev/null || echo "jammy")"
  fi

  ui_info "Configuring Docker repository for Ubuntu '${codename}' (${ARCH_DEB})..."
  echo \
    "deb [arch=${ARCH_DEB} signed-by=${DOCKER_KEYRING}] https://download.docker.com/linux/ubuntu ${codename} stable" \
    | tee "${DOCKER_LIST}" > /dev/null

  # 4. Install Docker Engine, CLI, and plugins
  ui_info "Installing Docker Engine and Compose plugins..."
  apt-get update -qq
  apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  # 5. Enable and start docker service
  systemctl enable --now docker >/dev/null 2>&1 || true

  # 6. Add target user to docker group
  if [[ -n "${TARGET_USER:-}" && "$TARGET_USER" != "root" ]]; then
    ui_info "Adding user '$TARGET_USER' to docker group..."
    usermod -aG docker "$TARGET_USER"
  fi

  # 7. Verification
  if command -v docker >/dev/null 2>&1; then
    local d_ver compose_ver
    d_ver="$(docker --version)"
    compose_ver="$(docker compose version 2>/dev/null || echo "unknown")"
    ui_success "Docker installed: ${d_ver}"
    ui_success "Docker Compose installed: ${compose_ver}"
  else
    ui_err "Docker installation could not be verified."
    return 1
  fi
}
