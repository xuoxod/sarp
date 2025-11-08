#!/usr/bin/env bash
set -euo pipefail

# Smoke test for scaffold_rust.sh (dry-run)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SC="$ROOT_DIR/scaffold_rust.sh"

if [[ ! -f "$SC" ]]; then
  echo "MISSING: $SC" >&2
  exit 2
fi

TMPDIR=$(mktemp -d)
OUT=$(mktemp)
trap 'rm -rf "$TMPDIR" "$OUT"' EXIT

# Run scaffold in dry-run and avoid requiring cargo
SCAFFOLD_DEBUG=1 bash "$SC" -d "$TMPDIR" --dry-run --no-cargo-init >"$OUT" 2>&1 || true

if grep -qi "dry run" "$OUT" || grep -qi "(dry)" "$OUT"; then
  echo "SMOKE-OK"
  exit 0
else
  echo "SMOKE-FAIL" >&2
  sed -n '1,200p' "$OUT" >&2
  exit 1
fi
