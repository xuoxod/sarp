#!/usr/bin/env bash
set -euo pipefail

# run_all.sh - local test runner for SARP scaffold tests
# Usage: ./run_all.sh [--skip-slow]

SKIP_SLOW=0
if [[ ${1:-} == "--skip-slow" ]]; then
	SKIP_SLOW=1
fi

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$ROOT_DIR/tests"

echo "Running unit tests..."
bash "$TEST_DIR/preview_summary_test.sh"
bash "$TEST_DIR/preview_full_test.sh"

if [[ $SKIP_SLOW -eq 1 ]]; then
	echo "Skipping slow lifecycle tests (--skip-slow)"
	exit 0
fi

echo "Running lifecycle tests (this may take a minute)..."
bash "$TEST_DIR/install_uninstall_cycle.sh"
bash "$TEST_DIR/manifest_tamper_uninstall_test.sh"

echo "All tests passed"
