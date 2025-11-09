#!/usr/bin/env bash
set -euo pipefail

# install_uninstall_cycle.sh
# Run a full install -> verify -> uninstall cycle using an isolated HOME

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"

if [[ ! -f "$INSTALL_SH" ]]; then
  echo "Missing installer: $INSTALL_SH" >&2
  exit 2
fi

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

export HOME="$TMPHOME"

echo "Using temporary HOME=$HOME for safe test"

mkdir -p "$HOME/.local/bin"

echo "1) Dry-run install"
bash "$INSTALL_SH" --dry-run

echo "2) Real install (non-interactive)"
bash "$INSTALL_SH" --yes --force

SYMLINK="$HOME/.local/bin/sarp-scaffold"
if [[ -L "$SYMLINK" ]]; then
  echo "Symlink created: $SYMLINK -> $(readlink "$SYMLINK")"
else
  echo "Expected symlink missing: $SYMLINK" >&2
  ls -la "$HOME/.local/bin" || true
  exit 3
fi

echo "3) Run uninstall (promptless)"
bash "$INSTALL_SH" --yes --uninstall

if [[ -e "$SYMLINK" || -d "$HOME/.local/sarp" ]]; then
  echo "Uninstall failed: leftovers remain" >&2
  ls -la "$HOME/.local" || true
  exit 4
fi

echo "INSTALL/UNINSTALL cycle OK"
exit 0
