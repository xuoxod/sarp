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
  --no-cargo-init  Don't run 'cargo init'; create files manually
  --ci           Add a basic GitHub Actions CI workflow
  --git          Initialize a git repository and create initial commit
  -f, --force    Overwrite existing files when safe
  -h, --help     Show this help

Example:
  # prepare current empty dir as a binary crate, add CI and git
  ./scripts/scaffold_rust.sh -n mytool -t bin --ci --git -a "You <you@example.com>"
USAGE
}

# NOTE: This script is distributed with a small `lib/` bundle (scaffold_utils.sh,
# scaffold_requirements.sh and scaffold_notify.sh) and a `templates/` directory.
# When run from the original repository location the script sources those helpers
# and uses the full feature set (colorized logs, stricter validation, template
# rendering). To make the single-file script usable when copied into an empty
# project directory we provide minimal fallback implementations for a few
# helpers (path resolution, validate_target, logging shims). The fallbacks are
# intentionally conservative — they are enough for common workflows and dry-run
# usage but do not replace the full `lib/` behavior (symlink checking, advanced
# prompts and platform-specific heuristics). If you need the complete behavior,
# run the script from the repository root (or copy the `lib/` and `templates/`
# directories alongside the script).


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
    --record-manifest) RECORD_MANIFEST="$2"; shift 2 ;;
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

# Fallback helpers: make the script minimally portable if someone copies only
# this single file into a new (empty) project directory. We only define
# fallbacks for a small set of functions that the script uses unconditionally
# (so a full lib/ bundle is not strictly required for basic usage).
# These are only defined when the real helpers are not present.
type -t _abs_path >/dev/null 2>&1 || {
  _abs_path() {
    local p=${1:-.}
    # resolve to an absolute path; fall back to plain echo on failure
    if [[ -d "$p" ]]; then
      (cd "$p" 2>/dev/null && pwd) || { printf '%s' "$p"; return 0; }
    else
      # if it's a file or doesn't exist, return the parent dir + basename
      local dir; dir=$(dirname -- "$p")
      if (cd "$dir" 2>/dev/null); then
        printf '%s/%s' "$(pwd)" "$(basename -- "$p")"
      else
        printf '%s' "$p"
      fi
    fi
  }
}

type -t validate_target >/dev/null 2>&1 || {
  validate_target() {
    # validate_target <target> <create_dir_flag> <force_flag> <dry_run_flag>
    # Returns on stdout the absolute path when successful and uses exit
    # codes similar to the full lib implementation for compatibility:
    # 0 success
    # 2 refused (system dir or symlink to system path)
    # 3 not writable
    # 4 not empty and no --force
    # 5 not exists and --create not given
    # 6 cannot create (parent not writable)
    local target=${1:-.}
    local create=${2:-0}
    local force=${3:-0}
    local dry_run=${4:-0}

    if [[ -z "$target" ]]; then
      printf ''
      return 1
    fi

    # resolve symlinks if possible to check for system paths
    local abs
    abs=$(_abs_path "$target") || abs="$target"

    # refuse obvious system dirs
    case "$abs" in
      /|/bin|/sbin|/usr|/usr/bin|/usr/sbin|/etc|/proc|/sys|/dev|/boot|/root)
        printf '' >&2
        printf 'Refusing to scaffold into system directory: %s\n' "$abs" >&2
        return 2
        ;;
    esac

    # If path exists and is symlink resolve target
    if [[ -L "$abs" ]]; then
      local real
      real=$(_abs_path "$(readlink -f -- "$abs")") || real="$abs"
      case "$real" in
        /bin/*|/sbin/*|/usr/*|/etc/*|/root/*|/dev/*)
          printf 'Refusing to scaffold into symlink pointing to system path: %s -> %s\n' "$abs" "$real" >&2
          return 2
          ;;
      esac
    fi

    if [[ -e "$abs" ]]; then
      if [[ -d "$abs" ]]; then
        # check writability
        if [[ ! -w "$abs" ]]; then
          printf 'Directory exists but is not writable: %s\n' "$abs" >&2
          return 3
        fi
        # empty or only allowed files
        shopt -s dotglob nullglob
        local items=("$abs"/*)
        shopt -u dotglob nullglob
        if [[ ${#items[@]} -gt 0 ]]; then
          # allowed harmless files
          local allowed=(README.md .gitignore Cargo.toml)
          local extra=0
          for f in "${items[@]}"; do
            local b; b=$(basename -- "$f")
            local ok=0
            for a in "${allowed[@]}"; do [[ "$b" == "$a" ]] && ok=1 && break; done
            [[ $ok -eq 0 ]] && extra=1 && break
          done
          if [[ $extra -eq 1 && $force -ne 1 ]]; then
            printf 'Directory %s is not empty. Use --force to proceed.\n' "$abs" >&2
            return 4
          fi
        fi
      else
        printf 'Path exists and is not a directory: %s\n' "$abs" >&2
        return 2
      fi
    else
      # does not exist
      if [[ $create -ne 1 ]]; then
        printf 'Directory does not exist: %s (use --create to create)\n' "$abs" >&2
        return 5
      fi
      # check parent writability
      local parent; parent=$(dirname -- "$abs")
      if [[ ! -w "$parent" ]]; then
        printf 'Cannot create directory (parent not writable): %s\n' "$abs" >&2
        return 6
      fi
      # attempt to create unless dry-run
      if [[ $dry_run -ne 1 ]]; then
        mkdir -p -- "$abs" || { printf 'cannot create target: %s\n' "$abs" >&2; return 6; }
      fi
    fi

    printf '%s' "$abs"
    return 0
  }
}

# Minimal logging and helper shims used by the script so it remains usable
type -t header >/dev/null 2>&1 || header() { printf '%s\n' "$*" >&2; }
type -t info >/dev/null 2>&1 || info() { printf '%s\n' "$*" >&2; }
type -t notice >/dev/null 2>&1 || notice() { printf '%s\n' "$*" >&2; }
type -t warn >/dev/null 2>&1 || warn() { printf 'WARN: %s\n' "$*" >&2; }
type -t error >/dev/null 2>&1 || error() { printf 'ERROR: %s\n' "$*" >&2; }
type -t success >/dev/null 2>&1 || success() { printf '%s\n' "$*" >&2; }
type -t check_command >/dev/null 2>&1 || check_command() { command -v "$1" >/dev/null 2>&1; }
type -t suggest_install >/dev/null 2>&1 || suggest_install() { printf 'install %s via your distro package manager' "$1"; }

# propagate opts to utils
if [[ $NO_COLOR -eq 1 ]]; then SCAFFOLD_NO_COLOR=1; fi
if [[ $NO_HEADER -eq 1 ]]; then SCAFFOLD_NO_HEADER=1; fi
if [[ $ASSUME_YES -eq 1 ]]; then SCAFFOLD_ASSUME_YES=1; fi
# mark these variables as intentionally referenced to quiet shellcheck warnings
: "${SCAFFOLD_NO_COLOR:-}"
: "${SCAFFOLD_NO_HEADER:-}"
: "${SCAFFOLD_ASSUME_YES:-}"

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
  # validate_target may print warnings; capture full output then extract the
  # final non-empty line which should be the absolute path. Any diagnostic
  # lines printed earlier are ignored for the assignment.
  if ! out=$(validate_target "$TARGET_DIR" "$CREATE_DIR" "$FORCE" "$DRY_RUN"); then
    error "Target validation failed for: $TARGET_DIR"
    exit 3
  fi
  TARGET_ABS=$(printf '%s
' "$out" | awk 'NF{last=$0} END{print last}')
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
# shellcheck disable=SC2317
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
  if [[ "$mode" == "x" ]]; then
    chmod 0755 "$path"
  else
    chmod 0644 "$path"
  fi
  # record into manifest if set and not a dry run
  if [[ -n "${RECORD_MANIFEST:-}" && ${DRY_RUN:-0} -eq 0 ]]; then
    _compute_sha256() {
      local f="$1" s=""
      if command -v sha256sum >/dev/null 2>&1; then
        s=$(sha256sum -- "$f" 2>/dev/null | awk '{print $1}') || s=""
      elif command -v shasum >/dev/null 2>&1; then
        s=$(shasum -a 256 -- "$f" 2>/dev/null | awk '{print $1}') || s=""
      elif command -v openssl >/dev/null 2>&1; then
        s=$(openssl dgst -sha256 -- "$f" 2>/dev/null | awk '{print $NF}') || s=""
      fi
      printf '%s' "$s"
    }
    abs=$(readlink -f -- "$path" 2>/dev/null || true)
    checksum=$(_compute_sha256 "$path" || true)
    # write as tab-separated: <abs-path>\t<sha256> (sha256 may be empty)
    printf '%s\t%s\n' "${abs:-$path}" "${checksum}" >> "$RECORD_MANIFEST" 2>/dev/null || true
  fi
  echo "created: $path"
}

# helper: render a template file with simple placeholders into destination
write_template() {
  local tmpl="$1" dest="$2"
  if [[ ! -f "$tmpl" ]]; then
    echo "template missing: $tmpl" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  # Replace placeholders: __NAME__, __AUTHOR__, __EDITION__, __LICENSE__
  sed -e "s/__NAME__/${NAME//\//\\\//}/g" \
      -e "s/__AUTHOR__/${AUTHOR//\//\\\//}/g" \
      -e "s/__EDITION__/${EDITION//\//\\\//}/g" \
      -e "s/__LICENSE__/${LICENSE_CHOICE//\//\\\//}/g" \
      "$tmpl" > "$dest"
  chmod 0644 "$dest"
  if [[ -n "${RECORD_MANIFEST:-}" && ${DRY_RUN:-0} -eq 0 ]]; then
    abs=$(readlink -f -- "$dest" 2>/dev/null || true)
    checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
      checksum=$(sha256sum -- "$dest" 2>/dev/null | awk '{print $1}') || checksum=""
    elif command -v shasum >/dev/null 2>&1; then
      checksum=$(shasum -a 256 -- "$dest" 2>/dev/null | awk '{print $1}') || checksum=""
    elif command -v openssl >/dev/null 2>&1; then
      checksum=$(openssl dgst -sha256 -- "$dest" 2>/dev/null | awk '{print $NF}') || checksum=""
    fi
    printf '%s\t%s\n' "${abs:-$dest}" "${checksum}" >> "$RECORD_MANIFEST" 2>/dev/null || true
  fi
  echo "created: $dest"
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
      # render from template
      TEMPLATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates"
      write_template "$TEMPLATES_DIR/Cargo.toml.tmpl" Cargo.toml || true
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
          write_template "$TEMPLATES_DIR/main.rs.tmpl" src/main.rs || true
        fi
      fi
  else
      if [[ ! -f src/lib.rs || $FORCE -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          info "(dry) write src/lib.rs"
        else
          write_template "$TEMPLATES_DIR/lib.rs.tmpl" src/lib.rs || true
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
      write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/lib.rs.tmpl" src/lib.rs || true
      echo "created: src/lib.rs"
    fi
  fi
fi

# README
if [[ ! -f README.md || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create README.md"
  else
    write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/README.md.tmpl" README.md || true
    echo "created: README.md"
  fi
fi

# .gitignore
if [[ ! -f .gitignore || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create .gitignore"
  else
    write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/gitignore.tmpl" .gitignore || true
    echo "created: .gitignore"
  fi
fi

# rustfmt config
if [[ ! -f rustfmt.toml || $FORCE -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    info "(dry) create rustfmt.toml"
  else
    write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/rustfmt.toml.tmpl" rustfmt.toml || true
    echo "created: rustfmt.toml"
  fi
fi

# LICENSE
create_license() {
  local lic="$1"
  if [[ "$lic" == "MIT" ]]; then
    local year
    year=$(date +%Y)
    # render MIT license template
    write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/LICENSE-MIT.tmpl" "$TARGET_ABS/LICENSE" || true
    # substitute year and author in-place
    sed -i "s/__YEAR__/$year/g; s/__AUTHOR__/${AUTHOR//\//\\\//}/g" "$TARGET_ABS/LICENSE" || true
    echo "created: LICENSE (MIT)"
  elif [[ "$lic" == "Apache-2.0" ]]; then
    write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/LICENSE-APACHE.tmpl" "$TARGET_ABS/LICENSE" || true
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
      mkdir -p .github/workflows
      write_template "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates/ci.yml.tmpl" .github/workflows/ci.yml || true
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
