#!/usr/bin/env bash
set -euo pipefail

# Validate uninstall refuses when manifest header tampered, but succeeds with --force
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"

TMPHOME=$(mktemp -d)
export HOME="$TMPHOME"

# perform real install (non-dry)
bash "$INSTALL_SH" --yes || { echo "install failed"; exit 2; }

MANIFEST="$HOME/.local/sarp/.sarp-manifest"
if [[ ! -f "$MANIFEST" ]]; then
  echo "FAIL: manifest not created"
  rm -rf "$TMPHOME"
  exit 3
fi

# tamper the manifest header
sed -i '1s/.*/# BAD_MANIFEST v1/' "$MANIFEST"

# run uninstall and expect a non-zero exit (uninstall aborts without --force)
set +e
out=$(bash "$INSTALL_SH" --uninstall --yes 2>&1)
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
  echo "FAIL: uninstall succeeded despite tampered manifest (expected failure)"
  echo "Output:\n$out"
  rm -rf "$TMPHOME"
  exit 4
fi
if ! grep -q "Manifest format unrecognized" <<<"$out"; then
  echo "FAIL: did not detect manifest tampering message"
  echo "Output:\n$out"
  rm -rf "$TMPHOME"
  exit 5
fi

# Now uninstall with --force (should succeed)
bash "$INSTALL_SH" --uninstall --yes --force || { echo "FAIL: forced uninstall failed"; rm -rf "$TMPHOME"; exit 6; }

# verify removal
if [[ -d "$HOME/.local/sarp" || -L "$HOME/.local/bin/sarp-scaffold" ]]; then
  echo "FAIL: artifacts not removed after forced uninstall"
  rm -rf "$TMPHOME"
  exit 7
fi

echo "MANIFEST TAMPER UNINSTALL TEST: OK"
rm -rf "$TMPHOME"
exit 0
