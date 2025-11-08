#!/usr/bin/env bash
# Fail-safe notification helper for scaffold scripts
# Exposes:
# - scaffold_notify <title> <message>
# - scaffold_notify_available (returns 0 if a graphical/daemon notifier is available)

set -euo pipefail

# Try to detect common notification backends on Linux
_scaffold_notify_detect_backend() {
  if command -v zenity >/dev/null 2>&1; then
    printf 'zenity'
    return 0
  fi
  if command -v yad >/dev/null 2>&1; then
    printf 'yad'
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    printf 'notify-send'
    return 0
  fi
  if command -v kdialog >/dev/null 2>&1; then
    printf 'kdialog'
    return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    printf 'whiptail'
    return 0
  fi
  return 1
}

scaffold_notify_available() {
  if _scaffold_notify_detect_backend >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

scaffold_notify() {
  # scaffold_notify <title> <message>
  local title=${1:-"scaffold"}
  local msg=${2:-""}
  # optional third argument urgency for notify-send
  local urgency=${3:-}

  local backend
  backend=$(_scaffold_notify_detect_backend || true)

  case "$backend" in
    zenity)
      # zenity --info --text="$msg"
      # Use --no-wrap to rely on the dialog's default handling; --ellipsize available in newer zenity
      zenity --info --title="$title" --text="$msg" --no-wrap >/dev/null 2>&1 || true
      return 0
      ;;
    yad)
      yad --title="$title" --text="$msg" --button=OK >/dev/null 2>&1 || true
      return 0
      ;;
    "notify-send")
      if [[ -n "$urgency" ]]; then
        notify-send -u "$urgency" "$title" "$msg" >/dev/null 2>&1 || true
      else
        notify-send "$title" "$msg" >/dev/null 2>&1 || true
      fi
      return 0
      ;;
    kdialog)
      kdialog --title "$title" --msgbox "$msg" >/dev/null 2>&1 || true
      return 0
      ;;
    whiptail)
      whiptail --title "$title" --msgbox "$msg" 12 60 >/dev/null 2>&1 || true
      return 0
      ;;
    *)
      # No graphical notifier available; fallback to printing
      printf '%s: %s\n' "$title" "$msg" >&2
      return 1
      ;;
  esac
}

export -f scaffold_notify scaffold_notify_available
