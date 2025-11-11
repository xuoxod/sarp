#!/usr/bin/env bash
set -euo pipefail
# cleanup_test_artifacts.sh
# Robust, fail-safe test artifact cleaner for the sarp scaffold tests.
# Usage: cleanup_test_artifacts.sh [--manifest FILE] [--dry-run] [--force] [--allow PREFIX] [paths...]
# - If --manifest FILE is provided, reads newline-separated paths from it (ignores # comments).
# - By default only removes paths under an allowlist: repo root (if available) and /tmp, /var/tmp.
# - --allow PREFIX adds an allowed prefix (may be used multiple times).
# - --dry-run prints actions without deleting.
# - --force bypasses the allowlist (use with extreme caution).

MANIFEST=""
DRY_RUN=0
FORCE=0
ASSUME_YES=0
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=""
if git_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null || true); then
  repo_root="$git_root"
else
  repo_root=$(cd "$script_dir/../.." && pwd)
fi
declare -a ALLOW_PREFIXES
ALLOW_PREFIXES=("/tmp" "/var/tmp" "$repo_root")

usage(){
  cat <<-USAGE
Usage: $(basename "$0") [options] [paths...]

Options:
  --manifest FILE   Read paths from FILE (one per line). Lines starting with # are ignored.
  --allow PREFIX    Allow deletion under PREFIX (may be repeated).
  --dry-run         Show what would be removed without performing deletions.
  --force           Bypass allowlist (DANGEROUS).
  -h|--help         Show this help

This tool safely moves listed paths into a quarantine directory and then
removes the quarantine when not in dry-run mode. It refuses to operate on
critical system directories and only allows deletions under an allowlist
unless --force is specified.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --manifest) MANIFEST=$2; shift 2 ;;
    --allow) ALLOW_PREFIXES+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
  -y|--yes) ASSUME_YES=1; shift ;;
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
    line=${line%%#*} # strip comments
    line=${line##+([[:space:]])}
    line=${line%%+([[:space:]])}
    [[ -z "$line" ]] && continue
    TARGETS+=("$line")
  done < "$MANIFEST"
fi

# remaining args are paths
for p in "$@"; do TARGETS+=("$p"); done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No targets specified. Use --manifest or provide paths." >&2; usage; exit 2
fi

# safety: disallow very short or root-like paths
is_critical_path() {
  local p=$1
  case "$p" in
    /|/bin|/sbin|/usr|/usr/bin|/usr/sbin|/etc|/proc|/sys|/dev|/boot|/root)
      return 0 ;;
    *) return 1 ;;
  esac
}

timestamp=$(date +%Y%m%dT%H%M%S)
quarantine="/tmp/sarp-cleanup-$timestamp-$$"
mkdir -p "$quarantine"
echo "Quarantine directory: $quarantine"

failures=0
declare -a MOVES

for t in "${TARGETS[@]}"; do
  # expand and resolve absolute path
  if abs=$(readlink -f -- "$t" 2>/dev/null || true); then
    :
  else
    abs="$t"
  fi
  if [[ -z "$abs" ]]; then
    echo "Skipping empty target: '$t'" >&2; failures=$((failures+1)); continue
  fi
  if is_critical_path "$abs"; then
    echo "Refusing to delete critical path: $abs" >&2; failures=$((failures+1)); continue
  fi

  allowed=0
  if [[ $FORCE -eq 1 ]]; then allowed=1; fi
  for pref in "${ALLOW_PREFIXES[@]}"; do
    # empty prefix skip
    [[ -z "$pref" ]] && continue
    # canonicalize prefix
    pref_abs=$(readlink -f -- "$pref" 2>/dev/null || true)
    case "$abs" in
      "$pref_abs"* ) allowed=1; break ;;
    esac
  done

  if [[ $allowed -ne 1 ]]; then
    echo "Skipping (not allowed): $abs" >&2; failures=$((failures+1)); continue
  fi
  # schedule move into quarantine (actual move performed after confirmation)
  dest="$quarantine/$(basename -- "$abs")-$(date +%s%N)"
  MOVES+=("$abs:$dest")
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run: the following moves would be performed:";
  for m in "${MOVES[@]}"; do
    IFS=":" read -r s d <<< "$m"
    echo "  $s -> $d"
  done
  echo "Dry-run complete. Quarantine not created."; exit $failures
fi

# If we're about to do destructive work, prompt for explicit confirmation unless --yes
if [[ $ASSUME_YES -ne 1 ]]; then
  echo "About to move ${#MOVES[@]} item(s) into quarantine: $quarantine"
  echo "Allowlist prefixes:"; for p in "${ALLOW_PREFIXES[@]}"; do echo "  $p"; done
  echo "Targets:";
  for m in "${MOVES[@]}"; do IFS=":" read -r s d <<< "$m"; echo "  $s"; done
  printf "Proceed with cleanup? [y/N]: " >&2
  read -r ans
  case "$ans" in
    y|Y) : ;;
    *) echo "Aborting cleanup."; exit 3 ;;
  esac
fi

# perform moves now that user confirmed
for m in "${MOVES[@]}"; do
  IFS=":" read -r abs dest <<< "$m"
  echo "Moving $abs -> $dest"
  if mv -- "$abs" "$dest" 2>/dev/null; then
    echo "Moved"
  else
    echo "mv failed, attempting copy+rm for $abs" >&2
    if cp -a -- "$abs" "$dest" 2>/dev/null; then
      rm -rf -- "$abs" || { echo "Failed to remove original $abs" >&2; failures=$((failures+1)); }
    else
      echo "Failed to copy $abs to quarantine" >&2; failures=$((failures+1)); continue
    fi
  fi
done

if [[ $failures -ne 0 ]]; then
  echo "One or more items were skipped or failed (see messages). Quarantine holds moved items: $quarantine" >&2
  exit 2
fi

# all items moved successfully; now remove quarantine contents
echo "Removing quarantine: $quarantine"
rm -rf -- "$quarantine"
echo "Cleanup complete"
exit 0
