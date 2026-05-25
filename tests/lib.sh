#!/usr/bin/env bash
set -euo pipefail

: "${WT_BIN:?WT_BIN must be set by test.sh}"
: "${WT_SHELL:?WT_SHELL must be set by test.sh}"

TEST_ROOTS=()
cleanup_tests() {
  if ((${#TEST_ROOTS[@]})); then
    rm -rf "${TEST_ROOTS[@]}"
  fi
}
trap cleanup_tests EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

assert_contains() {
  local needle="$1"
  local file="$2"
  grep -Fq -- "$needle" "$file" || {
    printf '%s\n' "--- $file ---" >&2
    cat "$file" >&2 || true
    fail "expected '$file' to contain: $needle"
  }
}

assert_not_contains() {
  local needle="$1"
  local file="$2"
  if grep -Fq -- "$needle" "$file"; then
    printf '%s\n' "--- $file ---" >&2
    cat "$file" >&2 || true
    fail "expected '$file' not to contain: $needle"
  fi
}

assert_match() {
  local pattern="$1"
  local file="$2"
  grep -Eq -- "$pattern" "$file" || {
    printf '%s\n' "--- $file ---" >&2
    cat "$file" >&2 || true
    fail "expected '$file' to match: $pattern"
  }
}

assert_not_match() {
  local pattern="$1"
  local file="$2"
  if grep -Eq -- "$pattern" "$file"; then
    printf '%s\n' "--- $file ---" >&2
    cat "$file" >&2 || true
    fail "expected '$file' not to match: $pattern"
  fi
}

new_test_root() {
  local root
  root="$(mktemp -d)"
  TEST_ROOTS+=("$root")
  printf '%s\n' "$root"
}

create_repo_fixture() {
  local root="$1"
  REMOTE="$root/remote.git"
  SRC="$root/src"
  REPO="$root/repo"

  git init -q --bare "$REMOTE"
  git clone -q "$REMOTE" "$SRC"
  git -C "$SRC" switch -q -c master
  git -C "$SRC" config user.email wt-test@example.com
  git -C "$SRC" config user.name 'wt test'
  printf 'base\n' > "$SRC/README.md"
  git -C "$SRC" add README.md
  git -C "$SRC" -c core.hooksPath=/dev/null commit -q -m init
  git -C "$SRC" push -q -u origin master

  git clone -q "$REMOTE" "$REPO"
  git -C "$REPO" config user.email wt-test@example.com
  git -C "$REPO" config user.name 'wt test'
}

create_repo_fixture_with_yarn() {
  local root="$1"
  create_repo_fixture "$root"
  git -C "$SRC" pull -q --ff-only
  : > "$SRC/yarn.lock"
  git -C "$SRC" add yarn.lock
  git -C "$SRC" -c core.hooksPath=/dev/null commit -q -m 'add yarn lock'
  git -C "$SRC" push -q
  git -C "$REPO" pull -q --ff-only
}
