Update repository description/homepage via API
=============================================

This helper demonstrates how to update repository metadata (description and homepage) using a GitHub personal access token.

Files:

- `update_repo_meta.sh` — small script that sends a PATCH to `https://api.github.com/repos/:owner/:repo`.

Usage examples
--------------

1) Dry-run (print the payload and curl command):

```bash
./scripts/sarp/update_repo_meta.sh --owner xuoxod --repo sarp --description "Short description" --homepage "https://github.com/xuoxod/sarp" --dry-run
```

2) Using environment token (recommended):

```bash
export GITHUB_TOKEN="ghp_..."
./scripts/sarp/update_repo_meta.sh --owner xuoxod --repo sarp --description "Idempotent Rust scaffolder + installer (SARP)." --homepage "https://github.com/xuoxod/sarp"
```

3) Passing token inline (less secure):

```bash
./scripts/sarp/update_repo_meta.sh --token ghp_... --owner xuoxod --repo sarp --description "..." --homepage "..."
```

Notes
-----

- The token needs `repo` scope for private repos, or `public_repo` for public-only changes. For organization-repos additional permissions may be required.
- The script requires `jq` to compose/print the JSON output. Install it with `sudo apt install jq` on Debian/Ubuntu.
- Keep tokens secret. Prefer using GitHub Actions secrets if automating in CI.
