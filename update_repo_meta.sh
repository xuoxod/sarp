#!/usr/bin/env bash
set -euo pipefail

# update_repo_meta.sh
# Small helper to update GitHub repo metadata (description, homepage) via REST API.
# Usage:
#   GITHUB_TOKEN=<token> ./update_repo_meta.sh --owner xuoxod --repo sarp --description "..." --homepage "..."
# or with token arg:
#   ./update_repo_meta.sh --token <token> --owner xuoxod --repo sarp --description "..."

prog=$(basename "$0")

usage() {
  cat <<-USAGE
Usage: $prog [options]

Options:
  --token TOKEN        Use TOKEN instead of env GITHUB_TOKEN
  --owner OWNER        Repository owner (default: xuoxod)
  --repo REPO          Repository name (default: sarp)
  --description TEXT   New repository description (quoted)
  --homepage URL       New homepage URL (quoted)
  --dry-run            Print the curl command instead of executing
  -h, --help           Show this help

Example:
  GITHUB_TOKEN=xxx $prog --owner xuoxod --repo sarp --description "New desc" --homepage "https://github.com/xuoxod/sarp"
USAGE
}

OWNER="xuoxod"
REPO="sarp"
DESCRIPTION=""
HOMEPAGE=""
TOKEN=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --homepage) HOMEPAGE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

AUTH_TOKEN=${TOKEN:-${GITHUB_TOKEN:-}}
if [[ -z "$AUTH_TOKEN" ]]; then
  echo "Error: no GITHUB_TOKEN provided. Export GITHUB_TOKEN or pass --token." >&2
  exit 2
fi

data='{}'
if [[ -n "$DESCRIPTION" ]]; then
  # escape double quotes
  esc_desc=${DESCRIPTION//"/\"}
  data=$(printf '%s' "$data" | jq --arg d "$esc_desc" '. + {description: $d}')
fi
if [[ -n "$HOMEPAGE" ]]; then
  esc_home=${HOMEPAGE//"/\"}
  data=$(printf '%s' "$data" | jq --arg h "$esc_home" '. + {homepage: $h}')
fi

if [[ "$data" == '{}' ]]; then
  echo "Nothing to update. Provide --description and/or --homepage." >&2
  exit 0
fi

API_URL="https://api.github.com/repos/$OWNER/$REPO"

cmd=(curl -sS -X PATCH -H "Authorization: token ${AUTH_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -d @- "$API_URL")

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: will run the following command with JSON payload on stdin:"
  printf '%s\n' "${cmd[*]}"
  echo "Payload:" >&2
  echo "$data" | jq .
  exit 0
fi

# Execute and show result
echo "$data" | jq -c . | ${cmd[@]} -
echo

# Check response (brief):
resp=$(echo "$data" | curl -sS -X PATCH -H "Authorization: token ${AUTH_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -d @- "$API_URL")
if echo "$resp" | jq -e .id >/dev/null 2>&1; then
  echo "Repository metadata updated successfully."
  echo "$resp" | jq '{full_name: .full_name, description: .description, homepage: .homepage, html_url: .html_url}'
  exit 0
else
  echo "Failed to update repository metadata. Response:" >&2
  echo "$resp" | jq .
  exit 3
fi
