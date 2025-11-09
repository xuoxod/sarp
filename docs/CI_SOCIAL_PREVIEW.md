Social preview generation — CI workflow
=====================================

This document explains how the `generate-social-preview.yml` workflow works and what (if anything) you need to do locally.

What the workflow does

- Runs on manual dispatch (`workflow_dispatch`).
- Installs `librsvg2-bin` on the runner and uses `rsvg-convert` to render `scripts/sarp/assets/social_preview.png` from the committed SVG.
- If the generated PNG differs from the committed file, the workflow commits and pushes the PNG back to the repository using the workflow's token.

When you need to run git commands locally

- I committed the new files (SVG, helpers, templates, tests, docs and the workflow) inside the `scripts/sarp` git repository on your machine. Those commits are local until you push them to the remote.
- To make the commits available on GitHub (so Actions and other collaborators can see them), push them:

From the repository root:

```bash
git -C scripts/sarp push origin main
```

Or push from inside the `scripts/sarp` directory:

```bash
cd scripts/sarp
git push origin main
```

Notes

- If your repository has branch protection that prevents Actions from pushing, the workflow's commit step may fail. In that case you can either:
  - allow GitHub Actions to push to that branch (in branch protection settings), or
  - create a Personal Access Token (PAT) with repo permissions, store it as a repo secret (e.g., `PNG_PUSH_TOKEN`), and update the workflow to use that secret for pushing.
- The workflow is intentionally manual to avoid unexpected commits; you can change its trigger to `push` if you'd like automatic regeneration on every change.
