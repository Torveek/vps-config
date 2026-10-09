#!/usr/bin/env bash
# ==============================================================================
# lib/ui.sh - Charm 'gum' UI wrappers with ANSI fallback
# ==============================================================================

# ANSI colors for fallback
ANSI_RESET="\033[0m"
ANSI_BOLD="\033[1m"
ANSI_DIM="\033[2m"
ANSI_RED="\033[31m"
ANSI_GREEN="\033[32m"
ANSI_YELLOW="\033[33m"
ANSI_BLUE="\033[34m"
ANSI_MAGENTA="\033[35m"
ANSI_CYAN="\033[36m"
ANSI_GRAY="\033[90m"

has_gum() {
  command -v gum >/dev/null 2>&1 && [ -t 1 ]
}

ui_header() {
  local title="$1"
  local subtitle="${2:-}"
  if has_gum; then
    if [ -n "$subtitle" ]; then
      gum style \
        --border rounded \
        --border-foreground 212 \
        --padding "1 3" \
        --margin "1 0" \
        --align center \
        "$(gum style --bold --foreground 212 "$title")" \
        "$(gum style --foreground 245 "$subtitle")"
    else
      gum style \
        --border rounded \
        --border-foreground 212 \
        --padding "1 3" \
        --margin "1 0" \
        --align center \
        "$(gum style --bold --foreground 212 "$title")"
    fi
  else
    echo -e "\n${ANSI_BOLD}${ANSI_MAGENTA}=== ${title} ===${ANSI_RESET}"
    if [ -n "$subtitle" ]; then
      echo -e "${ANSI_DIM}${subtitle}${ANSI_RESET}"
    fi
    echo ""
  fi
}

ui_step() {
  local msg="$1"
  if has_gum; then
    gum style --bold --foreground 39 "==> $msg"
  else
    echo -e "${ANSI_BOLD}${ANSI_BLUE}==>${ANSI_RESET} ${ANSI_BOLD}$msg${ANSI_RESET}"
  fi
}

ui_info() {
  local msg="$1"
  if has_gum; then
    echo "$(gum style --foreground 39 " [i] ") $msg"
  else
    echo -e "${ANSI_BLUE} [i] ${ANSI_RESET}$msg"
  fi
}

ui_success() {
  local msg="$1"
  if has_gum; then
    echo "$(gum style --foreground 48 --bold " [+] ") $msg"
  else
    echo -e "${ANSI_GREEN} [+] ${ANSI_RESET}$msg"
  fi
}

ui_warn() {
  local msg="$1"
  if has_gum; then
    echo "$(gum style --foreground 214 --bold " [!] ") $msg"
  else
    echo -e "${ANSI_YELLOW} [!] ${ANSI_RESET}$msg"
  fi
}

ui_err() {
  local msg="$1"
  if has_gum; then
    echo "$(gum style --foreground 196 --bold " [x] ") $msg" >&2
  else
    echo -e "${ANSI_RED} [x] ${ANSI_RESET}$msg" >&2
  fi
}

ui_input() {
  local prompt_text="$1"
  local default_val="${2:-}"
  local placeholder="${3:-}"
  
  if has_gum; then
    gum input --prompt "$prompt_text: " --value "$default_val" --placeholder "$placeholder"
  else
    local resp
    if [ -n "$default_val" ]; then
      read -r -p "$prompt_text [$default_val]: " resp
      echo "${resp:-$default_val}"
    else
      read -r -p "$prompt_text: " resp
      echo "$resp"
    fi
  fi
}

ui_password() {
  local prompt_text="$1"
  local placeholder="${2:-}"
  
  if has_gum; then
    gum input --password --prompt "$prompt_text: " --placeholder "$placeholder"
  else
    local resp
    read -r -s -p "$prompt_text: " resp
    echo "" >&2
    echo "$resp"
  fi
}

ui_confirm() {
  local prompt_text="$1"
  local default_choice="${2:-yes}" # yes or no
  
  if has_gum; then
    if [ "$default_choice" = "yes" ]; then
      gum confirm --default=true "$prompt_text"
    else
      gum confirm --default=false "$prompt_text"
    fi
  else
    local prompt_suffix="[Y/n]"
    [ "$default_choice" = "no" ] && prompt_suffix="[y/N]"
    read -r -p "$prompt_text $prompt_suffix " resp
    resp="$(echo "$resp" | tr '[:upper:]' '[:lower:]')"
    if [ -z "$resp" ]; then
      [ "$default_choice" = "yes" ] && return 0 || return 1
    fi
    [[ "$resp" =~ ^(y|yes)$ ]] && return 0 || return 1
  fi
}
