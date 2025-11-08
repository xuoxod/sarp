# Quick GitHub Actions tutorial (concise, friendly)

This short guide explains what the workflow we added does, why it helps, and how to roll it back if you change your mind.

What the workflow does

- Triggers: runs on pushes and pull requests targeting `main`.
- Steps:
  - Checks out the code.
  - Installs `shellcheck` and `markdownlint` (best-effort) for linting.
  - Runs `shellcheck` against shell scripts (reports issues but does not fail the job by default).
  - Runs `bash -n` to validate shell syntax (this will fail the job when syntax errors are present).
  - Runs `markdownlint` over the repository README (best-effort).
  - Executes the smoke test `scripts/tests/scaffold_smoke_test.sh` to ensure the scaffold behaves as expected in a clean runner.

Why this is useful (short)

- Automates checks so you don't have to run them locally every time.
- Catches syntax errors and common shell pitfalls early.
- Runs the smoke test in a clean environment similar to your VM so you get reproducible results.

How to view runs

- On GitHub: go to your repo → Actions → pick a run and inspect logs per step.

How to add safely (what we did)

- We created a workflow file in `.github/workflows/ci.yml`. The file is just code in the repo — adding it does not change any settings outside your repository.

How to remove or roll back the workflow

- If you haven't merged the branch you can simply delete the branch. If it is on `main`, remove the file and push the change:

```bash
git rm .github/workflows/ci.yml
git commit -m "ci: remove workflow"
git push
```

Or revert the commit that added the file.

Notes & tips

- The workflow is intentionally conservative: it focuses on linting and the smoke test and avoids running `cargo build` or modifying the runner persistently.
- If you later want to add a Rust build/test job, we can add a job that runs `cargo fmt -- --check`, `cargo build --release`, and `cargo test` in a separate job.
