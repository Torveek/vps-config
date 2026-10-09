# VPS Ubuntu Server Setup & Hardening

An interactive, modular VPS server configuration and hardening installer for **Ubuntu 22.04 LTS (Jammy)** and **Ubuntu 24.04 LTS (Noble)**.

Powered by Charm's [gum](https://github.com/charmbracelet/gum) for terminal UI with checkbox multi-selection menus.

---

## Features

- **Charm `gum` UI**: Bootstrapped first automatically, providing an interactive checkbox menu (`[Space]` to toggle components, `[Enter]` to confirm).
- **Sudo User Setup**: Prompted username and masked password prompt with automatic `sudo` group configuration.
- **SSH Hardening**:
  - Custom SSH Port (default: `2222`).
  - Interactive prompt for SSH public key installation in `~/.ssh/authorized_keys`.
  - Disables password authentication, PAM keyboard-interactive auth, and root login.
  - **Ubuntu 24.04 systemd socket fix**: Automatically resolves Ubuntu 24.04's `ssh.socket` activation override to ensure custom ports work seamlessly across cloud providers.
- **Zsh & Oh My Zsh**:
  - Clones Oh My Zsh.
  - Installs custom plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting`, `command-time`.
  - Installs [Starship](https://starship.rs/) prompt and [zoxide](https://github.com/ajeetdsouza/zoxide).
  - Deploys `.zshrc`, `.zsh_aliases`, `.zshenv`, `.zprofile`, and `starship.toml`.
  - Sets Zsh as the default shell for the target user.
- **Neovim & LazyVim**:
  - Installs modern **Neovim (v0.10+)** binary (overcoming Ubuntu 22.04's outdated apt package).
  - Installs prerequisites: `ripgrep`, `fd-find` (symlinked to `fd`), `build-essential`, `git`, `curl`.
  - Deploys full **LazyVim** configuration.
- **Docker & Docker Compose**:
  - Configures official Docker CE repository and GPG keyring for Ubuntu 22.04/24.04.
  - Installs Docker Engine, CLI, Containerd, Buildx, and Docker Compose plugin.
  - Adds target user to `docker` group for rootless docker commands.
- **Lazydocker**:
  - Installs the latest `lazydocker` terminal UI into `/usr/local/bin`.
- **Caddy Web Server**:
  - Installs official Caddy reverse proxy via Cloudsmith repository.
  - Configures and starts systemd service with a starter `Caddyfile`.
- **UFW Firewall & ICMP Echo Disabling**:
  - Enables UFW with incoming deny and outgoing allow policies.
  - Automatically opens custom SSH port, HTTP (`80`), and HTTPS (`443`).
  - Disables ICMP ping responses via kernel `sysctl` and UFW rules.

---

## Requirements

- **Operating System**: Ubuntu 22.04 LTS or Ubuntu 24.04 LTS (x86_64 or aarch64).
- **Privileges**: Root access (`sudo -i`).

---

## Quickstart

Run on your fresh VPS as root:

```bash
# 1. Clone repository
git clone https://github.com/Torveek/vps-config.git
cd vps-config

# 2. Run installer
sudo ./install.sh
```

---

## Directory Structure

```
vps-config/
├── install.sh                  # Main entrypoint script
├── config.env                  # Default configurations, versions & repository URLs
├── README.md                   # Documentation
├── lib/
│   ├── ui.sh                   # Gum UI styling, inputs & ANSI fallbacks
│   ├── system.sh               # OS detection, architecture & gum bootstrapper
│   ├── user.sh                 # User creation & sudo group setup
│   ├── ssh.sh                  # SSH port change, key injection & hardening
│   ├── zsh.sh                  # Zsh, Oh My Zsh, plugins, Starship & shell change
│   ├── neovim.sh               # Modern Neovim v0.10+ install & LazyVim config
│   ├── docker.sh               # Docker Engine & Docker Compose plugin
│   ├── lazydocker.sh           # Lazydocker installation
│   ├── caddy.sh                # Caddy web server & reverse proxy
│   └── firewall.sh             # UFW firewall & ICMP ping disable
└── dotfiles/
    ├── home/
    │   ├── .zshrc             # Shell configuration
    │   ├── .zsh_aliases       # Extended aliases & helper functions
    │   ├── .zshenv            # Environment variables
    │   └── .zprofile          # Session profile
    └── config/
        ├── starship.toml      # Decorated prompt configuration
        └── nvim/              # Full LazyVim setup
```

---

## Important Security Warning

> [!WARNING]
> When configuring SSH hardening, **DO NOT** close your current terminal session until you open a second terminal on your local machine and verify that you can successfully connect using:
> ```bash
> ssh -p <NEW_PORT> <USER>@<SERVER_IP>
> ```
