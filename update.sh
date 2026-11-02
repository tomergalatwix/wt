#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${WT_REPO_URL:-https://github.com/tomergalatwix/wt.git}"
REPO_REF="${WT_REPO_REF:-latest}"
REPO_RAW_ROOT="${WT_REPO_RAW_ROOT:-https://raw.githubusercontent.com/tomergalatwix/wt}"
REPO_RAW_BASE="${WT_REPO_RAW_BASE:-}"
tmp="$(mktemp "${TMPDIR:-/tmp}/wt-install.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

latest_release_tag() {
  git ls-remote --tags --refs "$REPO_URL" 'v*' 2>/dev/null |
    awk '{ tag = substr($2, 11) } tag ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { print tag }' |
    sort -t. -k1.2,1n -k2,2n -k3,3n | tail -n 1
}

resolve_repo_ref() {
  local ref="$REPO_REF" sha
  if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "$ref"
    return 0
  fi
  if [[ "$ref" == latest ]]; then
    ref="$(latest_release_tag || true)"
    ref="${ref:-master}"
  fi

  sha="$(git ls-remote "$REPO_URL" "refs/tags/$ref^{}" "refs/tags/$ref" "refs/heads/$ref" 2>/dev/null |
    awk '/\^\{\}$/ { peeled = $1 } !first { first = $1 } END { print peeled ? peeled : first }')"
  if [[ -z "$sha" ]]; then
    echo "Error: could not resolve $ref from $REPO_URL. Set WT_REPO_RAW_BASE to install from a custom source." >&2
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
