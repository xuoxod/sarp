# scripts/sarp

Repository helpers and small utilities for the SARP project.

## git-safe-push.sh

`git-safe-push.sh` is a small, conservative helper script that automates the common, safe workflow for reconciling a local branch with `origin` and pushing the reconciled result.

Why use it

- Creates a timestamped backup branch so you never lose the pre-reconcile state.
- Fetches `origin` and merges (or rebases) `origin/<branch>` into your local branch.
- Prompts before pushing the backup and before pushing the final branch (use `-y` to skip prompts).
- Supports `--dry-run` so you can preview the steps before running them.

Location

- `scripts/sarp/git-safe-push.sh`

Basic usage

Dry-run (no changes):

```bash
cd scripts/sarp
./git-safe-push.sh --branch main --dry-run
```

Run interactively and push backup + branch:

```bash
./git-safe-push.sh --branch main
```

Non-interactive (automatic yes):

```bash
./git-safe-push.sh --branch main -y
```

Use rebase instead of merge:

```bash
./git-safe-push.sh --branch main --rebase
```

Notes & safety

- The script is intentionally conservative. If a merge or rebase produces conflicts the script will stop and you must resolve them manually.
- The backup branch name defaults to `backup/auto-before-merge-<timestamp>`; you can change the prefix with `--backup-prefix`.

Optional Git alias

Add the following to your `~/.gitconfig` to make the helper available as `git safe-push`:

```ini
[alias]
    safe-push = !sh scripts/sarp/git-safe-push.sh --branch $(git rev-parse --abbrev-ref HEAD)
```

This assumes you run the alias from the repository root.

Want more?

- I can add a `Makefile` target, move the script into a `bin/` directory, or add a short unit-test that validates the dry-run output. Tell me which you'd prefer.

# Scaffold scripts — README

[![CI](https://github.com/xuoxod/sarp/actions/workflows/ci.yml/badge.svg)](https://github.com/xuoxod/sarp/actions/workflows/ci.yml)
[![Install lifecycle](https://github.com/xuoxod/sarp/actions/workflows/install-lifecycle.yml/badge.svg)](https://github.com/xuoxod/sarp/actions/workflows/install-lifecycle.yml)

This folder contains the Rust project scaffolding helpers and tests.

Short note about running a real scaffold (your "B" plan)

- The scaffold tool supports a safe `--dry-run` mode. That is the first place to validate behavior.
- If you want full confidence (your option B), running the real scaffold on a disposable VM is a great idea. Recommended steps:
  1. Create a snapshot or VM clone (so you can rollback if something goes wrong).
  2. Push this `scripts/` tree to a temporary GitHub repo (or copy it to the VM by scp). See "Upload to GitHub" below.
  3. On the VM, clone the repo, review `scripts/scaffold_rust.sh` and the helper scripts, then run the smoke test first:

```bash
git clone git@github.com:YOURNAME/your-repo.git
cd your-repo/scripts
bash tests/scaffold_smoke_test.sh
```

# 🔧 SARP — Scaffold A Rust Project

Welcome to SARP: a small, safe, and opinionated set of scripts that turn an empty directory into a nicely scaffolded Rust project. This repository contains the main `scaffold_rust.sh` orchestrator, helper libraries, and a smoke test so anyone (novice → power user) can try it safely.

Emoji key: 🚨 safety tip, ▶️ command/example, 🧪 test, ⚙️ configuration

---

## Quick facts

- Purpose: create a Rust project directory with Cargo.toml, sample code, README, LICENSE, .gitignore, rustfmt and (optionally) a CI workflow and git init.
- Safe modes: `--dry-run` (preview), smoke test (`scripts/tests/scaffold_smoke_test.sh`).
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
```

Note: there are additional unit tests under `tests/` such as `tests/test_validate_target.sh` which exercise
the scaffold fallback behavior and the manifest-driven cleanup helper. Run them from the `scripts/sarp` directory:

```bash
bash tests/test_validate_target.sh
```

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

# scripts/sarp

Repository helpers and small utilities for the SARP project.

## git-safe-push.sh

`git-safe-push.sh` is a small, conservative helper script that automates the common, safe workflow for reconciling a local branch with `origin` and pushing the reconciled result.

Why use it

- Creates a timestamped backup branch so you never lose the pre-reconcile state.
- Fetches `origin` and merges (or rebases) `origin/<branch>` into your local branch.
- Prompts before pushing the backup and before pushing the final branch (use `-y` to skip prompts).
- Supports `--dry-run` so you can preview the steps before running them.

Location

- `scripts/sarp/git-safe-push.sh`

Basic usage

Dry-run (no changes):

```bash
cd scripts/sarp
./git-safe-push.sh --branch main --dry-run
```

Run interactively and push backup + branch:

```bash
./git-safe-push.sh --branch main
```

Non-interactive (automatic yes):

```bash
./git-safe-push.sh --branch main -y
```

Use rebase instead of merge:

```bash
./git-safe-push.sh --branch main --rebase
```

Notes & safety

- The script is intentionally conservative. If a merge or rebase produces conflicts the script will stop and you must resolve them manually.
- The backup branch name defaults to `backup/auto-before-merge-<timestamp>`; you can change the prefix with `--backup-prefix`.

Optional Git alias

Add the following to your `~/.gitconfig` to make the helper available as `git safe-push`:

```ini
[alias]
    safe-push = !sh scripts/sarp/git-safe-push.sh --branch $(git rev-parse --abbrev-ref HEAD)
```

This assumes you run the alias from the repository root.

Want more?

- I can add a `Makefile` target, move the script into a `bin/` directory, or add a short unit-test that validates the dry-run output. Tell me which you'd prefer.

# Scaffold scripts — README

[![CI](https://github.com/xuoxod/sarp/actions/workflows/ci.yml/badge.svg)](https://github.com/xuoxod/sarp/actions/workflows/ci.yml)
[![Install lifecycle](https://github.com/xuoxod/sarp/actions/workflows/install-lifecycle.yml/badge.svg)](https://github.com/xuoxod/sarp/actions/workflows/install-lifecycle.yml)

This folder contains the Rust project scaffolding helpers and tests.

Short note about running a real scaffold (your "B" plan)

- The scaffold tool supports a safe `--dry-run` mode. That is the first place to validate behavior.
- If you want full confidence (your option B), running the real scaffold on a disposable VM is a great idea. Recommended steps:
  1. Create a snapshot or VM clone (so you can rollback if something goes wrong).
  2. Push this `scripts/` tree to a temporary GitHub repo (or copy it to the VM by scp). See "Upload to GitHub" below.
  3. On the VM, clone the repo, review `scripts/scaffold_rust.sh` and the helper scripts, then run the smoke test first:

```bash
git clone git@github.com:YOURNAME/your-repo.git
cd your-repo/scripts
bash tests/scaffold_smoke_test.sh
# 🔧 SARP — Scaffold A Rust Project

Welcome to SARP: a small, safe, and opinionated set of scripts that turn an empty directory into a nicely scaffolded Rust project. This repository contains the main `scaffold_rust.sh` orchestrator, helper libraries, and a smoke test so anyone (novice → power user) can try it safely.

Emoji key: 🚨 safety tip, ▶️ command/example, 🧪 test, ⚙️ configuration

---

## Quick facts

- Purpose: create a Rust project directory with Cargo.toml, sample code, README, LICENSE, .gitignore, rustfmt and (optionally) a CI workflow and git init.
- Safe modes: `--dry-run` (preview), smoke test (`scripts/tests/scaffold_smoke_test.sh`).
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

```

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
