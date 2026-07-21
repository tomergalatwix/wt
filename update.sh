#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${WT_REPO_URL:-https://github.com/tomergalatwix/wt.git}"
REPO_REF="${WT_REPO_REF:-master}"
REPO_RAW_ROOT="${WT_REPO_RAW_ROOT:-https://raw.githubusercontent.com/tomergalatwix/wt}"
REPO_RAW_BASE="${WT_REPO_RAW_BASE:-}"
tmp="$(mktemp -t wt-install.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

resolve_repo_ref() {
  if [[ "$REPO_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "$REPO_REF"
    return 0
  fi

  local sha
  sha="$(git ls-remote "$REPO_URL" "refs/heads/$REPO_REF" 2>/dev/null | awk '{ print $1; exit }')"
  if [[ -z "$sha" ]]; then
    echo "Error: could not resolve $REPO_REF from $REPO_URL. Set WT_REPO_RAW_BASE to install from a custom source." >&2
    exit 1
  fi
  printf '%s\n' "$sha"
}

repo_raw_base() {
  if [[ -n "$REPO_RAW_BASE" ]]; then
    printf '%s\n' "$REPO_RAW_BASE"
  else
    printf '%s/%s\n' "$REPO_RAW_ROOT" "$(resolve_repo_ref)"
  fi
}

raw_base="$(repo_raw_base)"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$raw_base/install.sh" -o "$tmp"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp" "$raw_base/install.sh"
else
  echo "Error: update requires curl or wget" >&2
  exit 1
fi

WT_REPO_RAW_BASE="$raw_base" bash "$tmp"
