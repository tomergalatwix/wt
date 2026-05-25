#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="${WT_REPO_RAW_BASE:-https://raw.githubusercontent.com/tomergalatwix/wt/master}"
tmp="$(mktemp -t wt-install.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$REPO_RAW_BASE/install.sh" -o "$tmp"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp" "$REPO_RAW_BASE/install.sh"
else
  echo "Error: update requires curl or wget" >&2
  exit 1
fi

bash "$tmp"
