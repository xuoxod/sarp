#!/usr/bin/env bash
set -euo pipefail

# install.sh - simple installer for SARP scaffold
# Installs files into $HOME/.local/sarp and symlinks the main entrypoint

TARGET_DIR="$HOME/.local/sarp"
BIN_DIR="$HOME/.local/bin"
SYMLINK_NAME="sarp-scaffold"
DRY_RUN=0
FORCE=0
PREVIEW=0
SUMMARY=0

usage(){
  cat <<EOF
Usage: install.sh [--yes] [--force] [--dry-run] [--uninstall]

Installs the SARP scaffold to: $TARGET_DIR
Creates symlink: $BIN_DIR/$SYMLINK_NAME -> $TARGET_DIR/scaffold_rust.sh

Options:
  --yes         Proceed without prompting
  --force       Overwrite existing install
  --dry-run     Print actions without performing them
  --preview     Print planned actions (alias: --plan). Implies --dry-run.
  --summary     Compact summary for --preview (shows counts and top-level entries)
  --uninstall   Remove installed files and symlink (safe remove)
EOF
}

UNINSTALL=0
while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --yes) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
  --preview|--plan) PREVIEW=1; DRY_RUN=1; shift ;;
  --summary|--brief) SUMMARY=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [[ $UNINSTALL -eq 1 ]]; then
  echo "Uninstalling SARP scaffold from: $TARGET_DIR"
  SYMLINK_PATH="$BIN_DIR/$SYMLINK_NAME"
  SYMLINKS_TO_REMOVE=()
  FILES_TO_REMOVE=()
  # Prefer manifest-based uninstall when available
  MANIFEST="$TARGET_DIR/.sarp-manifest"
  if [[ -f "$MANIFEST" ]]; then
    # validate manifest header
    read -r header < "$MANIFEST" || header=""
    if [[ "$header" != "# SARP_MANIFEST v1" ]]; then
      echo "Manifest format unrecognized; aborting uninstall unless --force" >&2
      if [[ $FORCE -ne 1 ]]; then
        exit 2
      fi
    fi
    # parse timestamp and check age
    manifest_ts=$(grep '^timestamp=' "$MANIFEST" 2>/dev/null | cut -d'=' -f2- || true)
    if [[ -n "$manifest_ts" ]]; then
      now_s=$(date -u +%s)
      manifest_s=$(date -ud "$manifest_ts" +%s 2>/dev/null || true)
      if [[ -n "$manifest_s" ]]; then
        age_days=$(( (now_s - manifest_s) / 86400 ))
        if [[ $age_days -gt 365 && $FORCE -ne 1 ]]; then
          echo "Manifest is $age_days days old; refuse to uninstall without --force" >&2
          exit 3
        fi
      fi
    fi

    # read files from manifest (skip header lines)
    while IFS= read -r line; do
      case "$line" in
        \#*|timestamp=*|installer=*) continue ;;
        "") continue ;;
        *)
          # only accept absolute paths
          if [[ "$line" == /* ]]; then
            FILES_TO_REMOVE+=("$line")
          fi
          ;;
      esac
    done < "$MANIFEST"
    # populate symlink list if present in manifest
    for p in "${FILES_TO_REMOVE[@]}"; do
      if [[ -L "$p" ]]; then
        SYMLINKS_TO_REMOVE+=("$p")
      fi
    done
  else
    # fallback heuristic: collect symlink and target files
    if [[ -L "$SYMLINK_PATH" ]]; then
      SYMLINKS_TO_REMOVE+=("$SYMLINK_PATH")
    elif [[ -e "$SYMLINK_PATH" ]]; then
      if [[ $FORCE -eq 1 ]]; then
        SYMLINKS_TO_REMOVE+=("$SYMLINK_PATH")
      fi
    fi
    if [[ -d "$TARGET_DIR" ]]; then
      if [[ -f "$TARGET_DIR/scaffold_rust.sh" ]]; then
        while IFS= read -r -d $'\0' f; do
          FILES_TO_REMOVE+=("$f")
        done < <(find "$TARGET_DIR" -print0)
      else
        if [[ $FORCE -eq 1 ]]; then
          while IFS= read -r -d $'\0' f; do
            FILES_TO_REMOVE+=("$f")
          done < <(find "$TARGET_DIR" -print0)
        fi
      fi
    fi
  fi

  # PATH export lines to consider removing (best-effort)
  PROFILE_LINES_TO_REMOVE=()
  if [[ -f "$HOME/.profile" && $(grep -n "${BIN_DIR}" "$HOME/.profile" || true) != "" ]]; then
    PROFILE_LINES_TO_REMOVE+=("$HOME/.profile")
  fi

  echo "The installer will remove the following items:" 
  if [[ ${#SYMLINKS_TO_REMOVE[@]} -gt 0 ]]; then
    echo "Symlinks/files:"
    for s in "${SYMLINKS_TO_REMOVE[@]}"; do echo "  - $s"; done
  fi
  if [[ ${#FILES_TO_REMOVE[@]} -gt 0 ]]; then
    echo "Installed files (under $TARGET_DIR):"
    for f in "${FILES_TO_REMOVE[@]}"; do echo "  - $f"; done
  fi
  if [[ ${#PROFILE_LINES_TO_REMOVE[@]} -gt 0 ]]; then
    echo "Profile changes (best-effort):"
    for p in "${PROFILE_LINES_TO_REMOVE[@]}"; do echo "  - will remove lines referencing $BIN_DIR in $p"; done
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY RUN: no changes will be made"
    exit 0
  fi

  if [[ ${YES:-0} -eq 0 ]]; then
    read -r -p "Proceed to remove the items listed above? [y/N] " conf
    if [[ ! "$conf" =~ ^[Yy] ]]; then
      echo "Aborted by user."; exit 0
    fi
  fi

  # perform removals
  for s in "${SYMLINKS_TO_REMOVE[@]}"; do
    echo "Removing: $s"
    rm -f -- "$s" || true
  done

  if [[ ${#FILES_TO_REMOVE[@]} -gt 0 ]]; then
    echo "Removing installed directory: $TARGET_DIR"
    rm -rf -- "$TARGET_DIR" || true
  fi

  # Attempt to remove PATH export from ~/.profile if present (best-effort)
  if [[ -f "$HOME/.profile" ]]; then
    if grep -q "$BIN_DIR" "$HOME/.profile"; then
      echo "Removing PATH modification from ~/.profile (best-effort)"
      cp "$HOME/.profile" "$HOME/.profile.bak" || true
      # filter lines that reference the exact BIN_DIR, write back
      awk -v bin="$BIN_DIR" 'index($0,bin)==0' "$HOME/.profile.bak" > "$HOME/.profile" || true
      echo "Backup written to ~/.profile.bak"
    fi
  fi

  echo "Uninstall complete."
  exit 0
fi

echo "Installing SARP scaffold to: $TARGET_DIR"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: no changes will be made"
fi

if [[ -d "$TARGET_DIR" && $FORCE -ne 1 ]]; then
  echo "Target $TARGET_DIR exists. Use --force to overwrite or remove it manually." >&2
  exit 1
fi

if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "$TARGET_DIR"
  mkdir -p "$BIN_DIR"
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $PREVIEW -eq 1 && $UNINSTALL -eq 0 ]]; then
  echo "PREVIEW: The installer would perform the following actions:"
  if [[ $SUMMARY -eq 1 ]]; then
    # compact summary: counts and top-level entries
    total_files=$(cd "$SRC_DIR" && find . -print | wc -l | tr -d '[:space:]')
    top_entries=$(cd "$SRC_DIR" && find . -maxdepth 1 -mindepth 1 -printf '%P\n' | head -n 20)
    echo "files to copy: $total_files (files+dirs)"
    echo "top-level entries (max 20):"
    while IFS= read -r e; do
      [[ -z "${e}" ]] && continue
      echo "  - ${e}"
    done <<EOF
${top_entries}
EOF
    echo "Would create symlink: $BIN_DIR/$SYMLINK_NAME -> $TARGET_DIR/scaffold_rust.sh"
    echo "Would write manifest to: $TARGET_DIR/.sarp-manifest"
    echo "Would add PATH export to ~/.profile: export PATH=\"$BIN_DIR:\$PATH\""
    exit 0
  fi
  echo "Would copy files from: $SRC_DIR -> $TARGET_DIR"
  # list source files and their destination mapping
  (cd "$SRC_DIR" && find . -print0 | while IFS= read -r -d $'\0' f; do
    if [[ "$f" == "." ]]; then continue; fi
    printf '  - %s -> %s\n' "$SRC_DIR/${f#./}" "$TARGET_DIR/${f#./}"
  done)
  echo "Would create symlink: $BIN_DIR/$SYMLINK_NAME -> $TARGET_DIR/scaffold_rust.sh"
  echo "Would write manifest to: $TARGET_DIR/.sarp-manifest (listing all installed files and the symlink)"
  echo "Would add PATH export to ~/.profile: export PATH=\"$BIN_DIR:\$PATH\""
  exit 0
fi

echo "Copying files from $SRC_DIR to $TARGET_DIR"
if [[ $DRY_RUN -eq 0 ]]; then
  rsync -a --delete "$SRC_DIR/" "$TARGET_DIR/"
  chmod +x "$TARGET_DIR/scaffold_rust.sh"
fi

SYMLINK_PATH="$BIN_DIR/$SYMLINK_NAME"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ -L "$SYMLINK_PATH" || -e "$SYMLINK_PATH" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      rm -f "$SYMLINK_PATH"
    else
      echo "Symlink $SYMLINK_PATH exists. Use --force to overwrite." >&2
      exit 1
    fi
  fi
  ln -s "$TARGET_DIR/scaffold_rust.sh" "$SYMLINK_PATH"
  echo "Created symlink: $SYMLINK_PATH -> $TARGET_DIR/scaffold_rust.sh"
else
  echo "Would create symlink: $SYMLINK_PATH -> $TARGET_DIR/scaffold_rust.sh"
fi

# Write manifest for safe uninstall (absolute paths)
MANIFEST="$TARGET_DIR/.sarp-manifest"
if [[ $DRY_RUN -eq 0 ]]; then
  echo "Writing manifest to $MANIFEST"
  # write manifest header with metadata
  TSTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Write manifest header and file list in one grouped write to avoid
  # multiple appends (addresses ShellCheck SC2129).
  {
    printf "%s\n" "# SARP_MANIFEST v1"
    printf "timestamp=%s\n" "$TSTAMP"
    printf "installer=%s\n" "${0##*/}"
    printf "# files follow (absolute paths)\n"
    # list all files under target dir (including directories), one per line
    (cd "$TARGET_DIR" && find . -print0 | while IFS= read -r -d $'\0' f; do printf '%s\n' "$(pwd)/${f#./}"; done)
    # append the symlink path so uninstall knows to remove it
    printf "%s\n" "$SYMLINK_PATH"
  } > "$MANIFEST"
fi

# Ensure $BIN_DIR is in PATH or offer to add it to shell rc
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: $BIN_DIR is not in your PATH. You may want to add it." >&2
  if [[ $DRY_RUN -eq 0 && ${YES:-0} -eq 0 ]]; then
    read -r -p "Add $BIN_DIR to your shell profile (~/.profile) now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy] ]]; then
      echo "export PATH=\"$BIN_DIR:\\$PATH\"" >> "$HOME/.profile"
      echo "Appended PATH export to ~/.profile"
    else
      echo "Skipping PATH change. You can add $BIN_DIR to your PATH manually." >&2
    fi
  elif [[ $DRY_RUN -eq 0 && ${YES:-0} -eq 1 ]]; then
    echo "export PATH=\"$BIN_DIR:\\$PATH\"" >> "$HOME/.profile"
    echo "Appended PATH export to ~/.profile"
  fi
fi

echo "Installation complete. Run: $SYMLINK_NAME --help or $TARGET_DIR/scaffold_rust.sh --help"

exit 0
