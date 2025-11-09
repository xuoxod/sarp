#!/usr/bin/env bash
set -euo pipefail

# Ensure full preview prints symlink and manifest lines
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"

out="$(bash "$INSTALL_SH" --preview 2>&1)"

if ! grep -q "Would create symlink" <<<"$out"; then
  echo "FAIL: preview did not list symlink"
  echo "Output:\n$out"
  exit 2
fi

if ! grep -q "Would write manifest" <<<"$out"; then
  echo "FAIL: preview did not mention manifest"
  echo "Output:\n$out"
  exit 3
fi

echo "PREVIEW FULL TEST: OK"
exit 0
