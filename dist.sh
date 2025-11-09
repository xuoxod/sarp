#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

# dist.sh - create a distribution tarball of the scaffold
# Usage: ./dist.sh [--outdir PATH]

OUTDIR="dist"
MODEL="sarp-scaffold"
TSTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BASENAME="${MODEL}-${TSTAMP}"
RUNDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --outdir) OUTDIR="$2"; shift 2 ;;
    -h|--help) echo "Usage: dist.sh [--outdir PATH]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

mkdir -p "$OUTDIR"

echo "Building distribution: $BASENAME.tar.gz from $RUNDIR"

# Only include scaffold-related files (scripts/sarp and lib and tests)
tar -czf "$OUTDIR/$BASENAME.tar.gz" -C "$RUNDIR" \
  scripts/sarp \
  scripts/sarp/* \
  lib || true

sha256sum "$OUTDIR/$BASENAME.tar.gz" > "$OUTDIR/$BASENAME.tar.gz.sha256"

echo "Created $OUTDIR/$BASENAME.tar.gz and checksum"
