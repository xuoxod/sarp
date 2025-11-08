#!/usr/bin/env bash
# scaffolding script to prepare an empty directory for a Rust project
# Target: Linux (Ubuntu). Usage: run inside the empty/new project directory.

#!/usr/bin/env bash
set -euo pipefail

progname=$(basename "$0")

usage() {
  cat <<-USAGE
Usage: $progname [options]

Prepare the current (empty) directory as a Rust project scaffold.

Options:
  -n NAME        Project name (default: current directory basename)
  -t TYPE        Project type: bin (default) or lib
  -e EDITION     Rust edition (2018|2021). Default: 2021
  -a AUTHOR      Author string to place in Cargo.toml and LICENSE
  -l LICENSE     License: MIT (default), Apache-2.0 or None
  --no-cargo-init  Don't run `cargo init`; create files manually
  --ci           Add a basic GitHub Actions CI workflow
  --git          Initialize a git repository and create initial commit
  -f, --force    Overwrite existing files when safe
  -h, --help     Show this help

Example:
  # prepare current empty dir as a binary crate, add CI and git
  ./scripts/scaffold_rust.sh -n mytool -t bin --ci --git -a "You <you@example.com>"
USAGE
}

### defaults
TYPE=bin
EDITION=2021
LICENSE_CHOICE=MIT
AUTHOR=""
NAME=""
DO_CARGO_INIT=1
DO_CI=0
DO_GIT=0
FORCE=0
DRY_RUN=0
CREATE_DIR=0
NO_COLOR=0
NO_HEADER=0
ASSUME_YES=0
WITH_CLAP=0
WITH_ANYHOW=0
WITH_SERDE=0
WITH_TRACING=0
WITH_TOKIO=0
NOTIFY=0
DO_CHECK=0

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NAME="$2"; shift 2 ;;
    -t) TYPE="$2"; shift 2 ;;
    -e) EDITION="$2"; shift 2 ;;
    -a) AUTHOR="$2"; shift 2 ;;
    -l) LICENSE_CHOICE="$2"; shift 2 ;;
    -d|--dir) TARGET_DIR="$2"; shift 2 ;;
    --no-cargo-init) DO_CARGO_INIT=0; shift ;;
    --ci) DO_CI=1; shift ;;
    --git) DO_GIT=1; shift ;;
    --create) CREATE_DIR=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-color) NO_COLOR=1; shift ;;
  --no-headers) NO_HEADER=1; shift ;;
  --check) DO_CHECK=1; shift ;;
  --with-clap) WITH_CLAP=1; shift ;;
  --with-anyhow) WITH_ANYHOW=1; shift ;;
  --with-serde) WITH_SERDE=1; shift ;;
  --with-tracing) WITH_TRACING=1; shift ;;
  --with-tokio) WITH_TOKIO=1; shift ;;
  --notify) NOTIFY=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -f|--force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

TARGET_DIR=${TARGET_DIR:-.}

# source helpers
SC_UTILS="$(dirname "$0")/lib/scaffold_utils.sh"
if [[ -f "$SC_UTILS" ]]; then
  # shellcheck source=/dev/null
  source "$SC_UTILS"
fi

SC_REQS="$(dirname "$0")/lib/scaffold_requirements.sh"
if [[ -f "$SC_REQS" ]]; then
  # shellcheck source=/dev/null
  source "$SC_REQS"
fi

SC_NOTIFY="$(dirname "$0")/lib/scaffold_notify.sh"
if [[ -f "$SC_NOTIFY" ]]; then
  # shellcheck source=/dev/null
  source "$SC_NOTIFY"
fi

# propagate opts to utils
if [[ $NO_COLOR -eq 1 ]]; then SCAFFOLD_NO_COLOR=1; fi
if [[ $NO_HEADER -eq 1 ]]; then SCAFFOLD_NO_HEADER=1; fi
if [[ $ASSUME_YES -eq 1 ]]; then SCAFFOLD_ASSUME_YES=1; fi

if [[ -z "$NAME" ]]; then
  NAME=$(basename "$(pwd)")
fi

# if author not provided, try git config
if [[ -z "$AUTHOR" ]]; then
  if command -v git >/dev/null 2>&1; then
    git_name=$(git config --get user.name || true)
    git_email=$(git config --get user.email || true)
    if [[ -n "$git_name" && -n "$git_email" ]]; then
      AUTHOR="$git_name <$git_email>"
    elif [[ -n "$git_name" ]]; then
      AUTHOR="$git_name"
    fi
  fi
fi

if [[ "$TYPE" != "bin" && "$TYPE" != "lib" && "$TYPE" != "both" ]]; then
  error "Unknown type: $TYPE"; exit 2
fi

header "Scaffolding Rust project '$NAME'"
info "type=$TYPE, edition=$EDITION, license=$LICENSE_CHOICE"
if [[ -n "$AUTHOR" ]]; then
  info "author=$AUTHOR"
fi

# validate target
TARGET_ABS=""
if [[ -n "${TARGET_DIR:-}" ]]; then
  # validate_target prints messages and returns abs path on stdout
  if ! TARGET_ABS=$(validate_target "$TARGET_DIR" "$CREATE_DIR" "$FORCE" "$DRY_RUN"); then
    error "Target validation failed for: $TARGET_DIR"
    exit 3
  fi
else
  TARGET_ABS=$(_abs_path .)
fi

info "target=$TARGET_ABS"

if [[ $DRY_RUN -eq 1 ]]; then
  notice "Dry run: no files will be written. Showing planned actions..."
fi

# If user asked for a check-only run
if [[ ${DO_CHECK:-0} -eq 1 ]]; then
  info "Performing system requirement checks"
  if [[ $DO_CARGO_INIT -eq 1 ]]; then
    if check_command cargo; then
      success "cargo available"
    else
      warn "cargo missing — $(suggest_install cargo)"
    fi
  fi
  if [[ $DO_GIT -eq 1 ]]; then
    if check_command git; then
      success "git available"
    else
      warn "git missing — $(suggest_install git)"
    fi
  fi
  if [[ $NOTIFY -eq 1 ]]; then
    if type -t scaffold_notify_available >/dev/null 2>&1 && scaffold_notify_available; then
      success "notification backend available"
    elif check_command zenity || check_command notify-send || [[ -n "${MESSAGE_SH:-}" && -x "${MESSAGE_SH}" ]]; then
      success "GUI/notification available"
    else
      warn "no notification tool found (zenity/notify-send/MESSAGE_SH). Install zenity or libnotify, or set MESSAGE_SH"
    fi
  fi
  exit 0
fi

# helper: write file if not exists or if FORCE
write_file() {
  local path="$1"; shift
  local mode=${1:-w}
  # caller supplies heredoc content on stdin
  if [[ -e "$path" && $FORCE -eq 0 ]]; then
    echo "skip: $path already exists (use -f to overwrite)"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  chmod 0644 "$path"
  echo "created: $path"
}

# Ensure cargo exists when we intend to use it
if [[ $DO_CARGO_INIT -eq 1 ]]; then
  if ! command -v cargo >/dev/null 2>&1; then
    error "cargo not found in PATH. Either install Rust (rustup) or pass --no-cargo-init."; exit 1
  fi
fi

# Run cargo init if requested
cd -- "$TARGET_ABS"

if [[ $DO_CARGO_INIT -eq 1 ]]; then
  if [[ -f Cargo.toml && $FORCE -eq 0 ]]; then
    notice "Cargo.toml exists in target, skipping cargo init (use -f to force)"
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      if [[ "$TYPE" == "both" ]]; then
        info "(dry) cargo init --bin --name $NAME && create src/lib.rs"
      else
        info "(dry) cargo init --name $NAME --${TYPE}"
      fi
    else
      if [[ "$TYPE" == "bin" ]]; then
        cargo init --bin --name "$NAME" .
      elif [[ "$TYPE" == "lib" ]]; then
        cargo init --lib --name "$NAME" .
      else
        # both: init as bin (so examples/buildable), then add lib file
        cargo init --bin --name "$NAME" .
      fi
    fi
    # cargo init creates Cargo.toml and src/ files; adjust edition and authors if provided
    if [[ -n "$AUTHOR" && $DRY_RUN -eq 0 ]]; then
      # stamp authors in Cargo.toml (naive replace)
      awk -v a="$AUTHOR" 'BEGIN{p=1} /\[package\]/{p=1} {print}' Cargo.toml > Cargo.toml.tmp && mv Cargo.toml.tmp Cargo.toml
    fi
    # ensure edition
    if [[ $DRY_RUN -eq 0 ]]; then
      if ! grep -q "^edition\s*=\s*\"$EDITION\"" Cargo.toml 2>/dev/null; then
        sed -E -i "s/^edition\s*=.*/edition = \"$EDITION\"/" Cargo.toml || true
      fi
    fi
  fi
else
  # No cargo init: create minimal Cargo.toml
  if [[ ! -f Cargo.toml || $FORCE -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "(dry) create Cargo.toml"
    else
      cat > Cargo.toml <<-TOML
[package]
name = "$NAME"
version = "0.1.0"
edition = "$EDITION"
authors = ["$AUTHOR"]
description = "${NAME} - scaffolded Rust project"
license = "${LICENSE_CHOICE}"

[dependencies]
TOML
      echo "created: Cargo.toml"
    fi
  else
    notice "skip: Cargo.toml exists"
  fi
  # create src
  mkdir -p src
  if [[ "$TYPE" == "bin" ]]; then
    if [[ ! -f src/main.rs || $FORCE -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          info "(dry) write src/main.rs"
        else
          cat > src/main.rs <<'MAIN'
  fn main() {
      println!("Hello, world!");
  }
  MAIN
          echo "created: src/main.rs"
        fi
      fi
  else
      if [[ ! -f src/lib.rs || $FORCE -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          info "(dry) write src/lib.rs"
        else
          cat > src/lib.rs <<'LIB'
  /// Library entrypoint
  pub fn hello() -> &'static str { "hello" }
  LIB
          echo "created: src/lib.rs"
        fi
      fi
  fi
fi

# If TYPE is both, ensure lib/main exist
if [[ "$TYPE" == "both" ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) ensure src/lib.rs exists"
  else
    if [[ ! -f src/lib.rs ]]; then
      cat > src/lib.rs <<'LIB'
/// Library entrypoint
pub fn hello() -> &'static str { "hello" }
LIB
      echo "created: src/lib.rs"
    fi
  fi
fi

# README
if [[ ! -f README.md || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create README.md"
  else
    cat > README.md <<-README
# $NAME

Scaffolded Rust project created with scripts/scaffold_rust.sh.

Build and run:

```sh
cargo build
cargo run -- --help
```

README
    echo "created: README.md"
  fi
fi

# .gitignore
if [[ ! -f .gitignore || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create .gitignore"
  else
    cat > .gitignore <<'GITIGNORE'
# Generated .gitignore for Rust
target/
**/*.rs.bk
**/*~
.DS_Store
Cargo.lock
.idea/
.vscode/
GITIGNORE
    echo "created: .gitignore"
  fi
fi

# rustfmt config
if [[ ! -f rustfmt.toml || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create rustfmt.toml"
  else
    cat > rustfmt.toml <<'RUSTFMT'
max_width = 100
RUSTFMT
    echo "created: rustfmt.toml"
  fi
fi

# LICENSE
create_license() {
  local lic="$1"
  if [[ "$lic" == "MIT" ]]; then
    local year=$(date +%Y)
    cat > LICENSE <<-MIT
MIT License

Copyright (c) $year ${AUTHOR}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
MIT
    echo "created: LICENSE (MIT)"
  elif [[ "$lic" == "Apache-2.0" ]]; then
    cat > LICENSE <<'APACHE'
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/
APACHE
    echo "created: LICENSE (Apache-2.0)"
  else
    echo "no license requested"
  fi
}

if [[ "$LICENSE_CHOICE" != "None" ]]; then
  if [[ ! -f LICENSE || $FORCE -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "(dry) create LICENSE ($LICENSE_CHOICE)"
    else
      create_license "$LICENSE_CHOICE"
    fi
  fi
fi

# Add a lightweight sample main.rs when cargo init created a stub lib or so
ensure_sample_main() {
  if [[ "$TYPE" == "bin" ]]; then
    if [[ ! -f src/main.rs || $FORCE -eq 1 ]]; then
      cat > src/main.rs <<'MAIN'
use clap::Parser;

#[derive(Parser)]
#[command(author, version, about = "A scaffolded Rust CLI", long_about = None)]
struct Cli {
    /// Example input
    #[arg(short, long)]
    input: Option<String>,
}

fn main() {
    let cli = Cli::parse();
    println!("Hello from scaffolded project! input={:?}", cli.input);
}
MAIN
      echo "wrote: src/main.rs (sample clap usage)"
    fi
  fi
}

ensure_sample_main

# if user requested auto dependencies, attempt to add them
add_requested_deps() {
  # only try when not dry-run
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    warn "cargo not found; skipping dependency installation"
    return 0
  fi
  if ! command -v cargo-add >/dev/null 2>&1 && ! command -v cargo-add >/dev/null 2>&1; then
    # cargo add is provided by cargo-edit as `cargo add`
    if ! command -v cargo >/dev/null 2>&1; then
      warn "cargo not available; cannot add dependencies"
      return 0
    fi
  fi
  # prefer builtin `cargo add` (cargo-edit). detect
  if command -v cargo >/dev/null 2>&1 && cargo add --version >/dev/null 2>&1 2>/dev/null; then
    local CA="cargo add"
  else
    # fallback: try to use `cargo` to add deps by editing Cargo.toml is not safe; warn
    warn "cargo-add (cargo add) not available; to auto-install deps, install cargo-edit"
    return 0
  fi

  if [[ $WITH_CLAP -eq 1 ]]; then
    info "adding dependency: clap"
    $CA clap --features derive
  fi
  if [[ $WITH_ANYHOW -eq 1 ]]; then
    info "adding dependency: anyhow"
    $CA anyhow
  fi
  if [[ $WITH_SERDE -eq 1 ]]; then
    info "adding dependency: serde (derive)"
    $CA serde --features derive
  fi
  if [[ $WITH_TRACING -eq 1 ]]; then
    info "adding dependency: tracing"
    $CA tracing
  fi
  if [[ $WITH_TOKIO -eq 1 ]]; then
    info "adding dependency: tokio (full)"
    $CA tokio --features full
  fi
}

add_requested_deps

# CI file

# Add CI workflow if requested
if [[ $DO_CI -eq 1 ]]; then
  if [[ ! -d .github/workflows || $FORCE -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "(dry) create .github/workflows"
    else
      mkdir -p .github/workflows
    fi
  fi
  if [[ ! -f .github/workflows/ci.yml || $FORCE -eq 1 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "(dry) create .github/workflows/ci.yml"
    else
      cat > .github/workflows/ci.yml <<'CI'
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rust
        uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: stable
      - name: Cache cargo registry
        uses: actions/cache@v4
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-registry-${{ hashFiles('**/Cargo.lock') }}
      - name: Build
        run: |
          cargo fmt -- --check || true
          cargo build --verbose
          cargo test --verbose
CI
      echo "created: .github/workflows/ci.yml"
    fi
  fi
fi

# Initialize git if requested
if [[ $DO_GIT -eq 1 ]]; then
  if [[ ! -d .git ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      info "(dry) git init && git add --all && git commit -m 'chore: scaffold $NAME'"
    else
      git init
      git add --all
      git commit -m "chore: scaffold $NAME"
      success "git repo initialized and initial commit made"
    fi
  else
    notice "git already initialized"
  fi
fi

cat <<-SUMMARY

Done. Project scaffolded: $NAME

Next steps:
  - Edit Cargo.toml (authors, description, dependencies)
  - Run: cargo build && cargo run
  - Add dependencies with: cargo add <crate>
  - If you didn't run --git, consider initializing version control

SUMMARY

# send optional desktop/GUI notification when requested
if [[ $NOTIFY -eq 1 ]]; then
  if type -t scaffold_notify >/dev/null 2>&1; then
    scaffold_notify "scaffold: $NAME" "Project scaffolded at $TARGET_ABS"
  else
    # utils.notify_message will prefer scaffold_notify if present; fall back to zenity/notify-send or console
    notify_message "Project scaffolded: $NAME ($TARGET_ABS)"
  fi
fi

exit 0
