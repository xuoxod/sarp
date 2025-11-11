
# scripts/sarp

Repository helpers and small utilities for the SARP project.

## git-safe-push.sh

`git-safe-push.sh` is a small, conservative helper script that automates the common, safe workflow for reconciling a local branch with `origin` and pushing the reconciled result.

Why use it

- Creates a timestamped backup branch so you never lose the pre-reconcile state.
- Fetches `origin` and merges (or rebases) `origin/<branch>` into your local branch.
- Prompts before pushing the backup and before pushing the final branch (use `-y` to skip prompts).
- Supports `--dry-run` so you can preview the steps before running them.

# SARP — scaffold and tests (scripts/sarp)

[![scaffold tests](https://github.com/xuoxod/netscan/actions/workflows/scaffold-tests.yml/badge.svg)](https://github.com/xuoxod/netscan/actions/workflows/scaffold-tests.yml)
[![unit tests](https://github.com/xuoxod/netscan/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/xuoxod/netscan/actions/workflows/unit-tests.yml)

A small collection of shell helpers and tests used to scaffold minimal Rust projects and safely test them in CI.

This README is intentionally concise. It describes what the scripts do, how to run the quick tests locally, the manifest format produced by the scaffold, and how the centralized cleanup helper consumes that manifest.

## Quick start

1. From the repository root, run the smoke test (read-only check):

```bash
# run the simple smoke test from repo root
bash scripts/sarp/tests/scaffold_smoke_test.sh
```

2. Run unit tests for helpers (fast):

```bash
bash scripts/sarp/tests/test_validate_target.sh
```

3. Try a dry-run scaffold into a temporary directory (no files written):

```bash
mkdir -p /tmp/sarp-test && cd /tmp/sarp-test
bash /absolute/path/to/repo/scripts/sarp/scaffold_rust.sh -n mytool -d . --dry-run
```

4. When you're ready, scaffold into a throwaway directory and enable CI/git as needed:

```bash
mkdir -p /tmp/sarp-real && cd /tmp/sarp-real
bash /absolute/path/to/repo/scripts/sarp/scaffold_rust.sh -n mytool -d . --ci --git
```

Note: replace `/absolute/path/to/repo` with your local repo path.

## Manifest format

When run with `--record-manifest /path/to/manifest`, the scaffold records each file it writes so test harnesses can clean up.

- Format: a single line per file with two tab-separated fields:

  - <absolute-path>\t<sha256>

- The sha256 field may be empty on systems without a checksum tool. The cleanup helper verifies the checksum (if present) before deleting.

Example line:

```text
/home/user/workspace/net-tool/README.md 3f786850e387550fdab836ed7e6dc881de23001b
```

## Safe cleanup helper

`scripts/sarp/lib/test_cleanup.sh` reads a manifest file created by the scaffold and removes only the recorded files.

Key behaviors:

- Verifies sha256 if present; skips and logs entries with mismatches unless `--force` is provided.
- Quarantines files first (attempts `mv`, falls back to `cp -a && rm -rf` if moving across devices), then removes quarantine.
- Writes an audit log to `/tmp/sarp-cleanup-<timestamp>-$$.log` for post-mortem.

Usage:

```bash
bash scripts/sarp/lib/test_cleanup.sh /path/to/manifest
```

Add `--force` to override checksum mismatches when you intentionally want to remove modified files.

## CI and tests

- The repo contains GitHub Actions workflows that run ShellCheck and the fast unit tests on PRs and pushes. The CI badges above link to the workflow runs.
- Locally, prefer running the unit tests before pushing:

```bash
bash scripts/sarp/tests/test_validate_target.sh
bash scripts/sarp/tests/scaffold_smoke_test.sh
```

If you want, I can run the test suite now and push this README to `main` (or open a branch + PR). Say which you prefer.

## Minimal file layout

```text
scripts/sarp/
├─ scaffold_rust.sh         # main scaffold entrypoint
├─ lib/
│  ├─ scaffold_utils.sh    # logging & helpers
│  └─ test_cleanup.sh      # manifest-driven cleanup helper
└─ tests/
   ├─ scaffold_smoke_test.sh
   └─ test_validate_target.sh
```

## Notes & contact

This module is purposely small and focused on test-safety. If you'd like, I can:

- run the fast tests now and commit & push this README to `main` (one-step), or
- create a branch and open a PR with the README + test run artifacts for review.

Pick one and I'll proceed.

- If `cargo` is missing: install Rust from <https://rustup.rs>.
- If `cargo add` is missing (auto-deps): `cargo install cargo-edit`.
- If notifications don't show: install `zenity` or `libnotify` (notify-send).

If anything behaves unexpectedly, open an issue or paste the script output here and I'll help diagnose.

---

Thanks for trying SARP — enjoy building small, tidy Rust projects. If you want, I can also add a friendly GitHub Actions workflow file on a branch so the repo runs the smoke test automatically when you push. Say the word and I'll create the branch and commit (no merge) so you can review it first.

- Location: this README lives at `scripts/sarp/README.md` inside the repo.

---

## Table of contents

1. What this does (brief)
2. Requirements
3. Quick start (novice-friendly)
4. Advanced usage (CI, deps, notify)
5. Safety checklist (VM snapshot, dry-run)
6. Files & layout (tree view)
7. Contributing / next steps

---

## 1) What this does (brief)

SARP automates the boring parts of creating a new Rust crate:

- creates `Cargo.toml` (or runs `cargo init`),
- writes `src/main.rs` or `src/lib.rs` sample code,
- creates `README.md`, `LICENSE`, `.gitignore`, `rustfmt.toml`, and optional GitHub Actions CI,
- provides helper scripts in `lib/` for logging, validation, requirements detection and desktop notifications,
- includes a smoke test to validate behavior on a clean machine.
- can record a manifest of created files (path + sha256) when run with `--record-manifest <file>`; this helps automated tests
   and cleanup tools remove only what the scaffold created.

Use it when you want a reproducible, minimal starting point for a new Rust project.

---

## 2) Requirements

- Host: Linux (Ubuntu-friendly). The scripts were developed and tested on Ubuntu. They may work on other POSIX systems but behaviour is not guaranteed.
- Shell: bash (the scripts use bash idioms and `set -euo pipefail`).
- Optional tools (recommended): `cargo`, `git`, `shellcheck` (for local linting), `zenity` or `notify-send` for GUI notifications.
- Disk: negligible. RAM: negligible for the scripts themselves; building Rust projects requires more.

If a required tool is missing the scripts will warn and (in many cases) continue in a safe fallback mode.

---

## 3) Quick start (novice-friendly)

Follow these steps to try SARP without risk.

1. Clone the repository (or copy `scripts/sarp` to your machine).

▶️ Quick clone example (replace `USER`):

```bash
git clone git@github.com:USER/sarp.git
cd sarp
```

1. Run the smoke test (read-only check):

🧪

```bash
bash tests/scaffold_smoke_test.sh

Note: there are additional unit tests under `tests/` such as `tests/test_validate_target.sh` which exercise
the scaffold fallback behavior and the manifest-driven cleanup helper. Run them from the `scripts/sarp` directory:

```bash
bash tests/test_validate_target.sh
```

```text

1. Try a dry-run of the scaffold in a temporary folder (no files will be written):

▶️

```bash
mkdir -p /tmp/sarp-test && cd /tmp/sarp-test
bash /path/to/sarp/scaffold_rust.sh -n mytool -d . --dry-run --no-cargo-init
```

1. If happy, run the real scaffold into a throwaway directory (not `/`):

▶️

```bash
mkdir -p /tmp/sarp-real && cd /tmp/sarp-real
bash /path/to/sarp/scaffold_rust.sh -n mytool -d . --ci --git
```

## 3.1) Install / one-liner (optional, review first)

If you want a painless local install so `sarp-scaffold` is available on your PATH, two safe approaches are supported. Always inspect scripts before running any remote one-liner.

1) From a checked-out repo (recommended):

```bash
# from repo root
bash scripts/sarp/install.sh --dry-run      # preview actions (recommended)
bash scripts/sarp/install.sh                 # perform install (asks for PATH change if needed)
```

2) From a distribution tarball (recommended for releases):

```bash
tar xzf dist/sarp-scaffold-<timestamp>.tar.gz -C /tmp
bash /tmp/sarp-scaffold-<timestamp>/scripts/sarp/install.sh --dry-run
bash /tmp/sarp-scaffold-<timestamp>/scripts/sarp/install.sh
```

3) One-line (not recommended without review):

```bash
# Only use if you trust the source and have reviewed the script.
curl -fsSL https://github.com/USER/sarp/raw/main/scripts/sarp/install.sh | bash -s -- --dry-run
# after review, run without --dry-run or run from a local copy
```

Security note: never run a shell script piped directly from the network without inspecting it. The recommended pattern is to `curl -fsSL ... -o install.sh` then open `install.sh` in your editor and run `bash install.sh --dry-run`.

Tip: use `--create` to allow creating the target directory if it doesn't exist.

---

## 4) Advanced usage

- Add dependencies automatically with `--with-clap`, `--with-serde`, `--with-tokio`, etc. (requires `cargo add` / cargo-edit).
- Use `--notify` to receive desktop notifications (uses `scaffold_notify.sh` which prefers `zenity`, `yad`, `notify-send`, then console).
- The script tries to be idempotent — it will not overwrite files unless `--force` is provided.

Manifest recording and cleanup

- Use `--record-manifest /path/to/manifest` when running the scaffold to record every file the scaffold writes.
  Each manifest line is written as a tab-separated pair: `<absolute-path>\t<sha256>` (sha256 may be empty if the
  platform lacks a checksum tool). The manifest is safe to pass to the centralized cleanup helper described below.

- A new cleanup helper `lib/test_cleanup.sh` reads such manifests and will verify recorded sha256 checksums before
  deleting entries. If a checksum mismatch is detected the entry is skipped and logged; pass `--force` to override
  and remove items despite mismatches. This improves test safety and auditability.

Example (create project, add CI and initialize git):

```bash
bash /path/to/sarp/scaffold_rust.sh -n net-tool -d ./net-tool --ci --git
```

---

## 5) Safety checklist (read before running on a real machine)

- Always run the smoke test first: `bash tests/scaffold_smoke_test.sh`.
- Use `--dry-run` to preview actions.
- Snapshot your VM or clone it before real runs so you can rollback.
- Don't use `--force` unless you intend to overwrite existing files.
- When in doubt, run the scaffold in `/tmp` first and inspect output.

🚨 If `validate_target` refuses your path, read the message — the script is protecting system directories.

---

## 6) Files & layout (tree view)

Here is the current `sarp/` layout (example):

```text
sarp/
├── README.md               # this file
├── scaffold_rust.sh        # main orchestrator (entrypoint)
├── .gitignore              # repo ignore rules
├── lib/
│   ├── scaffold_utils.sh   # logging, validation helpers
│   ├── scaffold_requirements.sh # detect pkg manager, suggest installs
│   └── scaffold_notify.sh  # fail-safe notifications (zenity/notify-send)
└── tests/
    └── scaffold_smoke_test.sh  # dry-run smoke test
```

Full tree (the one you probably saw locally):

```text
.
├── README.md
├── lib
│   ├── scaffold_notify.sh
│   ├── scaffold_requirements.sh
│   └── scaffold_utils.sh
├── scaffold_rust.sh
└── tests
    └── scaffold_smoke_test.sh

3 directories, 6 files
```

---

## 7) CI & tests (short)

CI (Continuous Integration) runs the smoke test and linters automatically on GitHub when you push. It helps catch environment differences and regressions early.

New workflow

- A workflow that runs ShellCheck and the scaffold unit tests has been added at `.github/workflows/scaffold-tests.yml`. It
  installs ShellCheck and fails the job on ShellCheck errors, runs `bash -n` checks and executes the fast scaffold tests.
  This helps catch scripting issues early in PRs and on `main` pushes.

If you'd like I can add a minimal workflow file on a branch (no merge) so you can review before enabling it.

### Running tests locally (recommended)

A small test runner is provided to run the unit and lifecycle tests locally. It mirrors what CI will execute and is useful before opening a PR.

Run the quick unit-only runner:

```bash
# run only fast unit tests
bash scripts/sarp/scripts/tests/run_all.sh --skip-slow
```

Run the full suite (includes install/uninstall lifecycle tests):

```bash
# may modify a throwaway HOME; tests use a temporary HOME and clean up after themselves
bash scripts/sarp/scripts/tests/run_all.sh
```

CI integration note

- The repository contains a GitHub Actions workflow that runs a fast `unit-tests` job first and, if those pass, runs a longer `lifecycle-tests` job that performs the install/uninstall lifecycle. This design minimizes cost and gives fast feedback for most changes.
- Wiring the local `run_all.sh` into CI (i.e., a CI step that simply calls the runner) is reasonable and reduces duplication between local and CI commands. The trade-offs:
  - Pros: single source of truth for test invocation; easier to maintain; local dev parity.
  - Cons: the runner may include helpers or environment assumptions that differ from the CI runner; ensure the script is idempotent and uses temporary HOME (it already does) before wiring it into CI.

Overall recommendation: wire the runner into CI (as a job step) for parity, but keep the existing split job structure (fast unit job + lifecycle job) to fail fast on quick checks.

---

## 8) Troubleshooting & tips

- If `cargo` is missing: install Rust from <https://rustup.rs>.
- If `cargo add` is missing (auto-deps): `cargo install cargo-edit`.
- If notifications don't show: install `zenity` or `libnotify` (notify-send).

If anything behaves unexpectedly, open an issue or paste the script output here and I'll help diagnose.

---

Thanks for trying SARP — enjoy building small, tidy Rust projects. If you want, I can also add a friendly GitHub Actions workflow file on a branch so the repo runs the smoke test automatically when you push. Say the word and I'll create the branch and commit (no merge) so you can review it first.
