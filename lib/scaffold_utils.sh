#!/usr/bin/env bash
# Utility helpers for scaffold_rust.sh
# - colorized logging (respect NO_COLOR / --no-color)
# - path resolution and target validation

set -euo pipefail

: ${SCAFFOLD_NO_COLOR:=0}
: ${SCAFFOLD_NO_HEADER:=0}

_supports_color() {
  # simple check: is stdout a tty and TERM supports color
  if [[ ${SCAFFOLD_NO_COLOR:-0} -eq 1 ]]; then
    return 1
  fi
  if [[ -t 1 ]]; then
    case "${TERM:-}" in
      xterm*|screen*|tmux*|rxvt*|vt100|linux) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 1
}

if _supports_color; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  MAGENTA='\033[0;35m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=''
  YELLOW=''
  GREEN=''
  CYAN=''
  MAGENTA=''
  BOLD=''
  RESET=''
fi

_log_prefix() { printf '%s' "[$1]"; }

header() {
  if [[ ${SCAFFOLD_NO_HEADER:-0} -eq 1 ]]; then return 0; fi
  printf "%b%s%b\n" "${BOLD}${CYAN}" "[H] $*" "${RESET}"
}

info() {
  printf "%b %b\n" "${CYAN} [i]${RESET}" "$*"
}

notice() {
  printf "%b %b\n" "${MAGENTA} [•]${RESET}" "$*"
}

warn() {
  printf "%b %b\n" "${YELLOW} [!]${RESET}" "$*"
}

error() {
  printf "%b %b\n" "${RED} [x]${RESET}" "$*" >&2
}

success() {
  printf "%b %b\n" "${GREEN} [✔]${RESET}" "$*"
}

debug() {
  if [[ ${SCAFFOLD_DEBUG:-0} -eq 1 ]]; then
    printf "%b %b\n" "${MAGENTA} [d]${RESET}" "$*"
  fi
}

custom_color_print() {
  # usage: custom_color_print <256-color-index> "message text"
  local color_index="$1"; shift || true
  local msg="$*"
  if _supports_color; then
    # 38;5;<n> sets 256-color foreground
    printf "\033[38;5;%sm%s%s\n" "$color_index" "$msg" "$RESET"
  else
    printf "%s\n" "$msg"
  fi
}

notify_message() {
  # Try: MESSAGE_SH env var -> zenity -> notify-send -> fallback to info
  local msg="$*"
  # Prefer a dedicated scaffold_notify function if provided by a notifier SOC
  if type -t scaffold_notify >/dev/null 2>&1; then
    scaffold_notify "scaffold" "$msg" || true
    return 0
  fi
  if [[ -n "${MESSAGE_SH:-}" && -x "${MESSAGE_SH}" ]]; then
    "${MESSAGE_SH}" "$msg" || true
    return 0
  fi
  if command -v zenity >/dev/null 2>&1; then
    zenity --info --text="$msg" --ellipsize || true
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "scaffold" "$msg" || true
    return 0
  fi
  # fallback to console output
  info "$msg"
}

_abs_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$p"
  else
    # fallback
    readlink -f -- "$p" || python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$p"
  fi
}

is_system_dir() {
  local p="$1"
  case "$p" in
    /|/bin|/sbin|/usr|/usr/bin|/usr/sbin|/etc|/proc|/sys|/dev|/boot)
      return 0 ;;
    /var/www|/root)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_under_system_dir() {
  local p="$1"
  for d in / /bin /sbin /usr /usr/bin /usr/sbin /etc /proc /sys /dev /boot; do
    if [[ "$p" == "$d"* ]]; then
      return 0
    fi
  done
  return 1
}

dir_writable() {
  local p="$1"
  if [[ -d "$p" ]]; then
    [[ -w "$p" ]]
  else
    # check parent
    [[ -w "$(dirname "$p")" ]]
  fi
}

dir_empty_or_only_allowed() {
  # allowed harmless files
  local d="$1"
  local allowed=(README.md .gitignore Cargo.toml)
  local count=0
  shopt -s dotglob nullglob
  local items=("$d"/*)
  shopt -u dotglob nullglob
  if [[ ${#items[@]} -eq 0 ]]; then
    return 0
  fi
  for f in "${items[@]}"; do
    local base=$(basename "$f")
    local ok=0
    for a in "${allowed[@]}"; do
      if [[ "$base" == "$a" ]]; then ok=1; break; fi
    done
    if [[ $ok -eq 0 ]]; then
      return 1
    fi
  done
  return 0
}

validate_target() {
  # args: target_path create_allowed force dry_run
  local target="$1"; shift
  local create_allowed=${1:-0}; shift || true
  local force=${1:-0}; shift || true
  local dry_run=${1:-0}; shift || true

  local abs=$(_abs_path "$target")
  debug "validate_target: resolved abs path=$abs"
  if is_system_dir "$abs"; then
    error "Refusing to scaffold into system directory: $abs"
    return 2
  fi
  if is_under_system_dir "$abs"; then
    warn "Target is under system path: $abs"
  fi

  if [[ -e "$abs" ]]; then
    debug "validate_target: path exists"
    if [[ -L "$abs" ]]; then
      debug "validate_target: path is symlink -> $(readlink -f "$abs")"
      local real=$(_abs_path "$(readlink -f "$abs")")
      if is_system_dir "$real"; then
        error "Refusing to scaffold into symlink pointing to system path: $abs -> $real"
        return 2
      fi
    fi
    if [[ -d "$abs" ]]; then
      debug "validate_target: is directory"
      if ! dir_writable "$abs"; then
        error "Directory exists but is not writable: $abs"
        return 3
      fi
      if ! dir_empty_or_only_allowed "$abs"; then
        debug "validate_target: directory is not empty"
        if [[ $force -ne 1 ]]; then
          warn "Directory $abs is not empty. Use --force to proceed."
          return 4
        else
          warn "Directory $abs is not empty but --force given; continuing"
        fi
      fi
    else
      debug "validate_target: path exists but is not a directory"
      error "Path exists and is not a directory: $abs"
      return 2
    fi
  else
    debug "validate_target: path does not exist"
    if [[ $create_allowed -ne 1 ]]; then
      error "Directory does not exist: $abs (use --create to create)"
      return 5
    fi
    # check parent writability
    if ! dir_writable "$abs"; then
      error "Cannot create directory (parent not writable): $abs"
      return 6
    fi
  fi

  # all good
  printf '%s' "$abs"
  return 0
}

confirm_prompt() {
  # prompt yes/no; return 0 for yes
  local prompt_text="$1"
  local default=${2:-no}
  if [[ ${SCAFFOLD_ASSUME_YES:-0} -eq 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    return 1
  fi
  local yn
  if [[ "$default" == "yes" ]]; then
    read -r -p "$prompt_text [Y/n]: " yn
    [[ -z "$yn" ]] && yn=y
  else
    read -r -p "$prompt_text [y/N]: " yn
  fi
  case "$yn" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

export -f header info warn error success debug _abs_path is_system_dir is_under_system_dir dir_writable dir_empty_or_only_allowed validate_target confirm_prompt
