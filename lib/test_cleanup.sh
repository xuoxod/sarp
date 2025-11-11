#!/usr/bin/env bash
set -euo pipefail
# test_cleanup.sh - centralized, hardened test cleanup helper
# Location: scripts/sarp/lib/test_cleanup.sh

# This is a refactoring of the previous cleanup helper to live under lib/
# Features:
# - manifest support (--manifest FILE)
# - dry-run, allowlist, --yes non-interactive
# - --confirm-manifest to require typing the manifest filename to confirm
# - --retain-quarantine to keep quarantine for inspection
# - audit log written to /tmp/sarp-cleanup-log-<timestamp>.txt

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=""
if git_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true); then
  repo_root="$git_root"
else
  repo_root=$(cd "$script_dir/../.." && pwd)
fi

MANIFEST=""
DRY_RUN=0
FORCE=0
ASSUME_YES=0
RETAIN_QUARANTINE=0
CONFIRM_MANIFEST=0
LOGFILE=""
declare -a ALLOW_PREFIXES
ALLOW_PREFIXES=("/tmp" "/var/tmp" "$repo_root")

usage(){
  cat <<-USAGE
Usage: $(basename "$0") [options] [paths...]

Options:
  --manifest FILE       Read paths from FILE (one per line). Lines starting with # are ignored.
  --allow PREFIX        Allow deletion under PREFIX (may be repeated).
  --dry-run             Show what would be removed without performing deletions.
  --force               Bypass allowlist (DANGEROUS).
  -y|--yes              Skip confirmation (non-interactive).
  --retain-quarantine   Keep quarantine after move for inspection.
  --confirm-manifest    Require typing the manifest filename to confirm.
  -h|--help             Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST=$2; shift 2 ;;
    --allow) ALLOW_PREFIXES+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --retain-quarantine) RETAIN_QUARANTINE=1; shift ;;
    --confirm-manifest) CONFIRM_MANIFEST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

declare -a TARGETS
if [[ -n "$MANIFEST" ]]; then
  if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifest not found: $MANIFEST" >&2; exit 2
  fi
  while IFS= read -r line; do
    line=${line%%#*}
    # trim leading/trailing whitespace (portable-ish)
    line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z "$line" ]] && continue
    # manifest format: <abs-path>\t<sha256> (sha256 optional). Split on tab and take first field
    IFS=$'\t' read -r path _checksum <<< "$line"
    TARGETS+=("$path")
  done < "$MANIFEST"
fi

for p in "$@"; do TARGETS+=("$p"); done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No targets specified. Use --manifest or provide paths." >&2; usage; exit 2
fi

is_critical_path(){ local p=$1; case "$p" in /|/bin|/sbin|/usr|/usr/bin|/usr/sbin|/etc|/proc|/sys|/dev|/boot|/root) return 0;; esac; return 1; }

timestamp=$(date +%Y%m%dT%H%M%S)
quarantine="/tmp/sarp-cleanup-$timestamp-$$"
mkdir -p "$quarantine"
LOGFILE="/tmp/sarp-cleanup-log-$timestamp-$$.txt"
echo "Quarantine directory: $quarantine" | tee "$LOGFILE"

declare -a MOVES
declare -a MOVES_CHECKSUMS
failures=0

for idx in "${!TARGETS[@]}"; do
  t=${TARGETS[$idx]}
  checksum=${TARGET_CHECKSUMS[$idx]:-}
  abs=$(readlink -f -- "$t" 2>/dev/null || true)
  [[ -z "$abs" ]] && abs="$t"
  if [[ -z "$abs" ]]; then echo "Skipping empty target: '$t'" | tee -a "$LOGFILE"; failures=$((failures+1)); continue; fi
  if is_critical_path "$abs"; then echo "Refusing critical path: $abs" | tee -a "$LOGFILE"; failures=$((failures+1)); continue; fi
  allowed=0; [[ $FORCE -eq 1 ]] && allowed=1
  for pref in "${ALLOW_PREFIXES[@]}"; do
    [[ -z "$pref" ]] && continue
    pref_abs=$(readlink -f -- "$pref" 2>/dev/null || true)
    case "$abs" in "$pref_abs"* ) allowed=1; break ;; esac
  done
  if [[ $allowed -ne 1 ]]; then echo "Skipping not allowed: $abs" | tee -a "$LOGFILE"; failures=$((failures+1)); continue; fi
  dest="$quarantine/$(basename -- "$abs")-$(date +%s%N)"
  MOVES+=("$abs:$dest:$checksum")
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run: planned moves:" | tee -a "$LOGFILE"
  for m in "${MOVES[@]}"; do IFS=":" read -r s d c <<< "$m"; echo "  $s -> $d (checksum:${c:-})" | tee -a "$LOGFILE"; done
  echo "Dry-run complete." | tee -a "$LOGFILE"
  exit $failures
fi

if [[ $CONFIRM_MANIFEST -eq 1 && -n "$MANIFEST" ]]; then
  echo "To confirm, type the manifest filename: $MANIFEST" | tee -a "$LOGFILE"
  read -r reply
  if [[ "$reply" != "$MANIFEST" ]]; then echo "Manifest confirmation failed; aborting" | tee -a "$LOGFILE"; exit 3; fi
fi

if [[ $ASSUME_YES -ne 1 ]]; then
  echo "About to move ${#MOVES[@]} items into quarantine: $quarantine" | tee -a "$LOGFILE"
  echo "Allowlist prefixes:" | tee -a "$LOGFILE"; for p in "${ALLOW_PREFIXES[@]}"; do echo "  $p" | tee -a "$LOGFILE"; done
  echo "Targets:" | tee -a "$LOGFILE"; for m in "${MOVES[@]}"; do IFS=":" read -r s d <<< "$m"; echo "  $s" | tee -a "$LOGFILE"; done
  printf "Proceed with cleanup? [y/N]: " >&2
  read -r ans
  case "$ans" in y|Y) : ;; *) echo "Aborting cleanup." | tee -a "$LOGFILE"; exit 3 ;; esac
fi

_compute_sha256() {
  local f="$1" s=""
  if command -v sha256sum >/dev/null 2>&1; then
    s=$(sha256sum -- "$f" 2>/dev/null | awk '{print $1}') || s=""
  elif command -v shasum >/dev/null 2>&1; then
    s=$(shasum -a 256 -- "$f" 2>/dev/null | awk '{print $1}') || s=""
  elif command -v openssl >/dev/null 2>&1; then
    s=$(openssl dgst -sha256 -- "$f" 2>/dev/null | awk '{print $NF}') || s=""
  fi
  printf '%s' "$s"
}

for m in "${MOVES[@]}"; do
  IFS=":" read -r abs dest expected_checksum <<< "$m"
  echo "Moving $abs -> $dest" | tee -a "$LOGFILE"
  # If we have an expected checksum, verify it before removal
  if [[ -n "${expected_checksum:-}" ]]; then
    if [[ -f "$abs" ]]; then
      actual=$(_compute_sha256 "$abs" || true)
      if [[ -z "$actual" || "$actual" != "$expected_checksum" ]]; then
        echo "Checksum mismatch or unavailable for $abs (expected: ${expected_checksum}, actual: ${actual:-<none>})" | tee -a "$LOGFILE"
        if [[ $FORCE -ne 1 ]]; then
          echo "Skipping $abs due to checksum mismatch (use --force to override)" | tee -a "$LOGFILE"
          failures=$((failures+1))
          continue
        else
          echo "--force provided, proceeding despite checksum mismatch" | tee -a "$LOGFILE"
        fi
      fi
    else
      echo "Target missing or not a regular file for checksum verification: $abs" | tee -a "$LOGFILE"
      failures=$((failures+1))
      continue
    fi
  fi

  if mv -- "$abs" "$dest" 2>/dev/null; then
    echo "Moved $abs" | tee -a "$LOGFILE"
  else
    echo "mv failed, trying cp+rm for $abs" | tee -a "$LOGFILE"
    if cp -a -- "$abs" "$dest" 2>/dev/null; then
      rm -rf -- "$abs" || { echo "Failed to remove original $abs" | tee -a "$LOGFILE"; failures=$((failures+1)); }
    else
      echo "Failed to copy $abs" | tee -a "$LOGFILE"
      failures=$((failures+1))
    fi
  fi
done

if [[ $failures -ne 0 ]]; then echo "Some items failed/skipped. Quarantine: $quarantine" | tee -a "$LOGFILE"; exit 2; fi

if [[ $RETAIN_QUARANTINE -eq 1 ]]; then
  echo "Quarantine retained at: $quarantine" | tee -a "$LOGFILE"
  echo "Audit log: $LOGFILE" | tee -a "$LOGFILE"
  exit 0
fi

echo "Removing quarantine: $quarantine" | tee -a "$LOGFILE"
rm -rf -- "$quarantine"
echo "Cleanup complete. Audit log: $LOGFILE" | tee -a "$LOGFILE"
exit 0
