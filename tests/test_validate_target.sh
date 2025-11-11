#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCAFFOLD="$SCRIPT_DIR/scaffold_rust.sh"

# source test helpers (manifest + cleanup helpers)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/tests/test_helpers.sh"

# initialize a manifest and install cleanup trap
test_manifest_init >/dev/null
test_manifest_install_trap

if [[ ! -x "$SCAFFOLD" ]]; then
  chmod +x "$SCAFFOLD" || true
fi

fail_count=0
pass_count=0

run_one() {
  local name=$1; shift
  echo "---- TEST: $name"
  out=$("$@" 2>&1) || rc=$? || true
  rc=${rc:-0}
  echo "exit=$rc"
  echo "$out"
  if [[ $rc -eq 0 ]]; then
    echo "OK: $name"
    pass_count=$((pass_count+1))
  else
    echo "FAIL: $name (rc=$rc)"
    fail_count=$((fail_count+1))
  fi
  echo
}

## manifest/trap are handled by test_helpers

# 1) Prepare an existing target and run a dry-run against it (should succeed)
tmp1=$(mktemp -d)
child1="$tmp1/newproj"
mkdir -p "$child1"
# record created artifact(s)
test_manifest_add "$tmp1"
set +e
out=$("$SCAFFOLD" --no-cargo-init --dry-run -d "$child1" 2>&1)
rc=$?
set -e
echo "exit=$rc"
echo "$out"
if [[ $rc -eq 0 ]]; then
  echo "OK: dry-run against existing target succeeded"; pass_count=$((pass_count+1)); echo
else
  echo "FAIL: dry-run against existing target failed"; fail_count=$((fail_count+1)); echo
fi

# 2) Non-empty dir with an extra file (should fail validation)
tmp2=$(mktemp -d)
echo hi > "$tmp2/random.txt"
test_manifest_add "$tmp2"
set +e
out=$("$SCAFFOLD" --no-cargo-init --dry-run -d "$tmp2" 2>&1)
rc=$?
set -e
echo "exit=$rc"; echo "$out"
if [[ $rc -ne 0 ]]; then
  echo "OK: non-empty dir rejected"; pass_count=$((pass_count+1)); echo
else
  echo "FAIL: non-empty dir should have been rejected"; fail_count=$((fail_count+1)); echo
fi

# 3) Non-empty dir with only allowed files (README.md) should pass
tmp3=$(mktemp -d)
touch "$tmp3/README.md"
test_manifest_add "$tmp3"
set +e
out=$("$SCAFFOLD" --no-cargo-init --dry-run -d "$tmp3" 2>&1)
rc=$?
set -e
echo "exit=$rc"; echo "$out"
if [[ $rc -eq 0 ]]; then
  echo "OK: allowed-files dir accepted"; pass_count=$((pass_count+1)); echo
else
  echo "FAIL: allowed-files dir should be accepted"; fail_count=$((fail_count+1)); echo
fi

# 4) Symlink to system dir should be refused
tmp4=$(mktemp -d)
ln -s /etc "$tmp4/linktoetc"
# record the temporary directory (not the symlink target) so cleanup does not
# resolve the symlink to a system path and refuse deletion.
test_manifest_add "$tmp4"
set +e
out=$("$SCAFFOLD" --no-cargo-init --dry-run -d "$tmp4/linktoetc" 2>&1)
rc=$?
set -e
echo "exit=$rc"; echo "$out"
if [[ $rc -ne 0 ]]; then
  echo "OK: symlink to system dir refused"; pass_count=$((pass_count+1)); echo
else
  echo "FAIL: symlink to system dir should be refused"; fail_count=$((fail_count+1)); echo
fi

# 5) Parent not writable when creating child should cause error
tmp5=$(mktemp -d)
chmod 0555 "$tmp5"
child5="$tmp5/newdir"
test_manifest_add "$tmp5"
set +e
out=$("$SCAFFOLD" --no-cargo-init --dry-run --create -d "$child5" 2>&1)
rc=$?
set -e
echo "exit=$rc"; echo "$out"
if [[ $rc -ne 0 ]]; then
  echo "OK: cannot create under non-writable parent"; pass_count=$((pass_count+1)); echo
else
  echo "FAIL: should have failed to create under non-writable parent"; fail_count=$((fail_count+1)); echo
fi

echo "Tests complete. Passed: $pass_count, Failed: $fail_count"
if [[ $fail_count -ne 0 ]]; then
  exit 2
fi
