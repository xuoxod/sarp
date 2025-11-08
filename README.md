# Scaffold scripts — README

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

Tip: use `--create` to allow creating the target directory if it doesn't exist.

---

## 4) Advanced usage

- Add dependencies automatically with `--with-clap`, `--with-serde`, `--with-tokio`, etc. (requires `cargo add` / cargo-edit).
- Use `--notify` to receive desktop notifications (uses `scaffold_notify.sh` which prefers `zenity`, `yad`, `notify-send`, then console).
- The script tries to be idempotent — it will not overwrite files unless `--force` is provided.

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

If you'd like I can add a minimal workflow file on a branch (no merge) so you can review before enabling it.

---

## 8) Troubleshooting & tips

- If `cargo` is missing: install Rust from <https://rustup.rs>.
- If `cargo add` is missing (auto-deps): `cargo install cargo-edit`.
- If notifications don't show: install `zenity` or `libnotify` (notify-send).

If anything behaves unexpectedly, open an issue or paste the script output here and I'll help diagnose.

---

Thanks for trying SARP — enjoy building small, tidy Rust projects. If you want, I can also add a friendly GitHub Actions workflow file on a branch so the repo runs the smoke test automatically when you push. Say the word and I'll create the branch and commit (no merge) so you can review it first.
