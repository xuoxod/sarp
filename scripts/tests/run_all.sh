#!/usr/bin/env bash
set -euo pipefail

echo "Running all tests for SARP (smoke tests)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_TEST="$SCRIPT_DIR/../../tests/scaffold_smoke_test.sh"
if [[ ! -f "$SMOKE_TEST" ]]; then
	echo "Smoke test not found: $SMOKE_TEST" >&2
	exit 2
fi
bash "$SMOKE_TEST"

echo "All tests completed"
