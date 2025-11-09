#!/usr/bin/env bash
set -euo pipefail

# Helper to generate a PNG social preview from the included SVG.
# Tries ImageMagick `convert`, then `rsvg-convert`, then Python Pillow fallback.

OUT=${1:-"$(dirname "$0")/assets/social_preview.png"}
SVG="$(dirname "$0")/assets/social_preview.svg"

if [[ ! -f "$SVG" ]]; then
  echo "SVG not found: $SVG" >&2
  exit 1
fi

echo "Generating social preview PNG -> $OUT"

if command -v convert >/dev/null 2>&1; then
  echo "Using ImageMagick 'convert'"
  convert -background none -resize 1200x630 "$SVG" "$OUT"
  echo "wrote: $OUT"
  exit 0
fi

if command -v rsvg-convert >/dev/null 2>&1; then
  echo "Using rsvg-convert"
  rsvg-convert -w 1200 -h 630 -o "$OUT" "$SVG"
  echo "wrote: $OUT"
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  echo "Trying Python Pillow fallback (requires pillow and cairosvg)
If not installed, run: pip install pillow cairosvg"
  python3 - <<'PY'
import sys
from pathlib import Path
svg = Path("""${SVG}""")
out = Path("""${OUT}""")
try:
    import cairosvg
    cairosvg.svg2png(url=str(svg), write_to=str(out), output_width=1200, output_height=630)
    print(f"wrote: {out}")
except Exception as e:
    print("Python fallback failed:", e, file=sys.stderr)
    sys.exit(2)
PY
  exit $? || true
fi

echo "No supported renderer found. You can upload the SVG at: $SVG as the social preview image in the repository Settings, or install ImageMagick/rsvg-convert." >&2
exit 2
