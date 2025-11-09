#!/usr/bin/env bash
set -euo pipefail

# Run uninstall preview in an isolated HOME with no existing install/manifest
TMPHOME=$(mktemp -d)
export HOME="$TMPHOME"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"

out="$(bash "$INSTALL_SH" --preview --uninstall 2>&1 || true)"

if ! grep -q "The installer will remove" <<<"$out"; then
  echo "FAIL: uninstall preview did not show removal section"
  echo "Output:\n$out"
  rm -rf "$TMPHOME"
  exit 2
fi

echo "UNINSTALL PREVIEW (no manifest) TEST: OK"
rm -rf "$TMPHOME"
exit 0
