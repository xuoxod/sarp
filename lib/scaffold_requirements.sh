#!/usr/bin/env bash
# Requirements detection helpers for scaffold_rust
# Purely detection and suggestion functionality; no side-effects.

set -euo pipefail

detect_pkg_manager() {
  if command -v apt >/dev/null 2>&1 || [[ -f /etc/debian_version ]]; then
    printf '%s' apt
  elif command -v dnf >/dev/null 2>&1 || [[ -f /etc/fedora-release ]]; then
    printf '%s' dnf
  elif command -v pacman >/dev/null 2>&1 || [[ -f /etc/arch-release ]]; then
    printf '%s' pacman
  else
    printf '%s' unknown
  fi
}

check_command() {
  # $1 = command name or check expression; returns 0 if available
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

suggest_install() {
  # $1 = command
  local cmd="$1"
  local pm
  pm=$(detect_pkg_manager)
  case "$cmd" in
    cargo)
      case "$pm" in
        apt) printf '%s' "sudo apt install rustup build-essential; rustup install stable; rustup default stable" ;;
        dnf) printf '%s' "sudo dnf install rust cargo" ;;
        pacman) printf '%s' "sudo pacman -S rust" ;;
        *) printf '%s' "Install Rust from https://rustup.rs" ;;
      esac ;;
    "cargo add"|cargo-add)
      printf '%s' "cargo-add is provided by cargo-edit. Install via: cargo install cargo-edit or your distro package manager (e.g. apt install cargo-edit)" ;;
    zenity)
      case "$pm" in
        apt) printf '%s' "sudo apt install zenity" ;;
        dnf) printf '%s' "sudo dnf install zenity" ;;
        pacman) printf '%s' "sudo pacman -S zenity" ;;
        *) printf '%s' "Install zenity via your package manager" ;;
      esac ;;
    notify-send)
      case "$pm" in
        apt) printf '%s' "sudo apt install libnotify-bin" ;;
        dnf) printf '%s' "sudo dnf install libnotify" ;;
        pacman) printf '%s' "sudo pacman -S libnotify" ;;
        *) printf '%s' "Install notify-send/libnotify via your package manager" ;;
      esac ;;
    git)
      printf '%s' "sudo apt install git (or use distro package manager)" ;;
    realpath|readlink)
      printf '%s' "coreutils (should be preinstalled). If missing, install coreutils via your package manager" ;;
    python3)
      printf '%s' "sudo apt install python3" ;;
    *) printf '%s' "Install $cmd via your package manager or from upstream" ;;
  esac
}

export -f detect_pkg_manager check_command suggest_install
