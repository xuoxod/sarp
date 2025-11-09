Social preview image for SARP
================================

Files added:

- `social_preview.svg` — an SVG badge-like image sized 1200×630 suitable for use as a social preview image on GitHub.
- `generate_social_preview.sh` — helper script to produce a PNG from the SVG (tries ImageMagick `convert`, `rsvg-convert`, or Python/cairosvg).

How to use
----------

1. Generate the PNG (optional):

```bash
# from repo root
bash scripts/sarp/generate_social_preview.sh
```

2. Upload the generated PNG (or the SVG) to GitHub: Repository → Settings → Options → Social preview → Upload image.

Notes
-----

- If `generate_social_preview.sh` fails due to missing tools, you can install ImageMagick (`sudo apt install imagemagick`) or `librsvg2-bin` (`sudo apt install librsvg2-bin`) or use Python's `cairosvg` (`pip install cairosvg`).
- The helper script is a convenience; you can also edit the SVG directly if you want different text/colors.

If you'd like I can also:

- Add an API helper (curl script) to update repository description/homepage (requires a token).
- Add a CI job to update the social preview automatically (requires a PAT stored as a repo secret).
