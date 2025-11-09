#!/usr/bin/env bash
set -euo pipefail

# Simple unit-style test for preview --summary output
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"

out="$(bash "$INSTALL_SH" --preview --summary 2>&1)"

# Check for essential markers
if ! echo "$out" | grep -q "files to copy:"; then
  echo "FAIL: preview summary did not contain 'files to copy:'"
  echo "Output:\n$out"
  exit 2
fi

if ! echo "$out" | grep -q "Would create symlink:"; then
  echo "FAIL: preview summary did not contain 'Would create symlink:'"
  echo "Output:\n$out"
  exit 3
fi

if ! echo "$out" | grep -q "top-level entries"; then
  echo "FAIL: preview summary did not list top-level entries"
  echo "Output:\n$out"
  exit 4
fi

echo "PREVIEW SUMMARY TEST: OK"
exit 0
