#!/usr/bin/env bash
set -euo pipefail
## Test helpers for scripts/sarp tests
## Provides manifest helpers to record created artifacts and perform safe cleanup

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

TEST_MANIFEST=""

test_manifest_init() {
  if [[ -n "${TEST_MANIFEST:-}" && -f "$TEST_MANIFEST" ]]; then
    return 0
  fi
  TEST_MANIFEST=$(mktemp /tmp/sarp-test-manifest.XXXXXX)
  printf '%s' "$TEST_MANIFEST"
}

test_manifest_add() {
  local p=${1:-}
  if [[ -z "$p" ]]; then return 0; fi
  if [[ -z "${TEST_MANIFEST:-}" ]]; then test_manifest_init >/dev/null; fi
  printf '%s\n' "$p" >> "$TEST_MANIFEST"
}

test_manifest_cleanup() {
  # If manifest missing, nothing to do
  if [[ -z "${TEST_MANIFEST:-}" || ! -f "$TEST_MANIFEST" ]]; then return 0; fi
  local helper="$SCRIPT_DIR/../lib/test_cleanup.sh"
  if [[ -x "$helper" ]]; then
    # call helper non-interactively (skip confirmation) and allow it to fail
    "$helper" --manifest "$TEST_MANIFEST" --yes || true
  else
    # fallback removal
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      rm -rf -- "$p" || true
    done < "$TEST_MANIFEST"
  fi
  rm -f "$TEST_MANIFEST" || true
}

test_manifest_install_trap() {
  # install a trap to call cleanup on EXIT
  trap test_manifest_cleanup EXIT
}

## End of helpers
