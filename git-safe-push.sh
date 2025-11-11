#!/usr/bin/env bash
set -euo pipefail

# git-safe-push.sh
# Helper to safely create a backup branch, fetch origin, merge (or rebase) origin/<branch>
# into the local branch, and push the reconciled branch to origin.
# Designed to be idempotent and conservative.

usage() {
  cat <<'USAGE'
Usage: git-safe-push.sh [options]

Options:
  -b, --branch NAME       Local branch to reconcile (default: main)
  --backup-prefix PREFIX  Backup branch prefix (default: backup/auto-before-merge-<timestamp>)
  --rebase                Use rebase instead of merge when reconciling with origin
  --no-push               Don't push the final reconciled branch to origin
  -y, --yes               Answer yes to prompts (non-interactive)
  --dry-run               Print actions but don't run them
  -h, --help              Show this help and exit

Example:
  ./git-safe-push.sh --branch main
  ./git-safe-push.sh --branch develop --rebase --dry-run
USAGE
}

BRANCH="main"
USE_REBASE=0
NO_PUSH=0
ASSUME_YES=0
DRY_RUN=0
BACKUP_PREFIX=""

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    -b|--branch) BRANCH="$2"; shift 2;;
    --backup-prefix) BACKUP_PREFIX="$2"; shift 2;;
    --rebase) USE_REBASE=1; shift;;
    --no-push) NO_PUSH=1; shift;;
    -y|--yes) ASSUME_YES=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; usage; exit 2;;
    *) break;;
  esac
done

timestamp() { date +%Y%m%d%H%M%S; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $*"
  else
    echo "+ $*" >&2
    eval "$@"
  fi
}

confirm() {
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " ans || return 1
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0;;
    *) return 1;;
  esac
}

# Move to repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  echo "Not inside a git repository." >&2
  exit 2
fi
cd "$REPO_ROOT"

CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$CURRENT" ]; then
  echo "Could not determine current branch." >&2
  exit 2
fi

# Compute backup branch name
if [ -n "$BACKUP_PREFIX" ]; then
  BACKUP_BRANCH="${BACKUP_PREFIX}-$(timestamp)"
else
  BACKUP_BRANCH="backup/auto-before-merge-$(timestamp)"
fi

echo "Repository: $REPO_ROOT"
echo "Current branch: $CURRENT"
echo "Target branch to reconcile: $BRANCH"
echo "Backup branch: $BACKUP_BRANCH"
echo "Reconcile mode: $( [ "$USE_REBASE" -eq 1 ] && echo rebase || echo merge )"
echo "Dry-run: $( [ "$DRY_RUN" -eq 1 ] && echo yes || echo no )"

# Create backup branch from current HEAD
if [ "$CURRENT" != "$BRANCH" ]; then
  echo "Switching to target branch $BRANCH to capture its state before operation."
  run git switch "$BRANCH" || run git checkout -b "$BRANCH"
fi

echo "Creating backup branch $BACKUP_BRANCH from branch $BRANCH"
run git branch "$BACKUP_BRANCH" || true
if [ "$DRY_RUN" -eq 0 ]; then
  if confirm "Push backup branch $BACKUP_BRANCH to origin?"; then
    run git push -u origin "$BACKUP_BRANCH" || true
  else
    echo "Skipping push of backup branch. Proceeding without remote backup." >&2
  fi
else
  echo "(dry-run) skipping push of backup branch"
fi

# Ensure we're on the branch to reconcile
run git switch "$BRANCH" || run git checkout -b "$BRANCH"

echo "Fetching origin..."
run git fetch origin

if [ "$USE_REBASE" -eq 1 ]; then
  echo "Rebasing $BRANCH onto origin/$BRANCH"
  if run git rebase "origin/$BRANCH"; then
    echo "Rebase succeeded"
  else
    echo "Rebase stopped with conflicts. Resolve conflicts, then run 'git rebase --continue' or abort with 'git rebase --abort'." >&2
    exit 3
  fi
else
  echo "Merging origin/$BRANCH into $BRANCH"
  if run git merge --no-edit "origin/$BRANCH"; then
    echo "Merge succeeded"
  else
    echo "Merge stopped with conflicts. Resolve conflicts, commit, then continue." >&2
    exit 4
  fi
fi

echo "Local status after reconcile:"
run git status --short --branch

if [ "$NO_PUSH" -eq 1 ]; then
  echo "--no-push specified; not pushing to origin. Done."
  exit 0
fi

if confirm "Push reconciled $BRANCH to origin?"; then
  run git push origin "$BRANCH"
  echo "Push complete."
else
  echo "Push cancelled by user. You can push manually with: git push origin $BRANCH" >&2
fi

echo "Done. Backup branch preserved as $BACKUP_BRANCH (if pushed)."
