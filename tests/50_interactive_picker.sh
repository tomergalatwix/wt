#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

root="$(new_test_root)"
create_repo_fixture "$root"
(cd "$REPO" && "$WT_BIN" grow --size 10 > /dev/null)
git -C "$REPO" worktree add -q "$root/repo-worktrees/work-one" -b work-one origin/master

fake_fzf="$root/fake-fzf"
cat > "$fake_fzf" <<'FAKE_FZF'
#!/usr/bin/env bash
set -euo pipefail
input="$(cat)"
case "$*" in
  *"Choose action:"*)
    [[ "$*" == *"Esc: exit"* && "$*" == *"Backspace: back"* ]] || exit 50
    if [[ -n "${WT_ASSERT_HEADER:-}" && "$*" != *"Chosen worktree: ${WT_ASSERT_HEADER}"* ]]; then
      echo "missing action header" >&2
      exit 51
    fi
    if [[ "${WT_ASSERT_NO_ALLOC:-0}" == 1 ]] && awk -F '\t' '$1 == "alloc" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "alloc should not be offered" >&2
      exit 52
    fi
    if [[ "${WT_ASSERT_HAS_ALLOC:-0}" == 1 ]] && ! awk -F '\t' '$1 == "alloc" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "alloc should be offered" >&2
      exit 53
    fi
    if [[ "${WT_ASSERT_NO_FREE:-0}" == 1 ]] && awk -F '\t' '$1 == "free" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "free should not be offered" >&2
      exit 54
    fi
    if [[ "${WT_ASSERT_HAS_FREE:-0}" == 1 ]] && ! awk -F '\t' '$1 == "free" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "free should be offered" >&2
      exit 55
    fi
    if [[ "${WT_ASSERT_HAS_REALLOC:-0}" == 1 ]] && ! awk -F '\t' '$1 == "realloc" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "realloc should be offered" >&2
      exit 56
    fi
    if [[ "${WT_ASSERT_HAS_REMOVE:-0}" == 1 ]] && ! awk -F '\t' '$1 == "remove" { found=1 } END { exit found ? 0 : 1 }' <<<"$input"; then
      echo "remove should be offered" >&2
      exit 57
    fi
    awk -F '\t' -v action="${WT_TEST_ACTION:-go}" '$1 == action { print; exit }' <<<"$input"
    ;;
  *)
    [[ "$*" == *"Esc: exit"* && "$*" == *"Backspace: exit"* ]] || exit 60
    if [[ "${WT_ASSERT_FREE_BOTTOM_LEX:-0}" == 1 ]]; then
      prev_free=""
      seen_free=0
      while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        if [[ "$name" == "__WT_GROW__" ]]; then
          continue
        elif [[ "$name" == free-* ]]; then
          if [[ "$seen_free" == 1 && "$name" < "$prev_free" ]]; then
            echo "free slots are not lexicographic" >&2
            exit 61
          fi
          seen_free=1
          prev_free="$name"
        elif [[ "$seen_free" == 1 ]]; then
          echo "non-free worktree after free slot: $name" >&2
          exit 62
        fi
      done < <(awk -F '\t' 'NR > 1 { print $2 }' <<<"$input")
    fi
    if [[ "${WT_SELECT_GROW:-0}" == 1 ]]; then
      awk -F '\t' '$2 == "__WT_GROW__" { print; exit }' <<<"$input"
    else
      awk -F '\t' -v name="${WT_SELECT_NAME:-main}" 'NR > 1 && $2 == name { print; exit }' <<<"$input"
    fi
    ;;
esac
FAKE_FZF
chmod +x "$fake_fzf"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_NAME=main WT_TEST_ACTION=go WT_ASSERT_HEADER=main WT_ASSERT_FREE_BOTTOM_LEX=1 "$WT_BIN")"
[[ "$output" == __WT_GO__* ]] || fail "expected go directive, got: $output"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_GROW=1 "$WT_BIN")"
assert_eq '__WT_GROW__' "$output"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_NAME=free-1 WT_TEST_ACTION=alloc WT_ASSERT_HAS_ALLOC=1 WT_ASSERT_NO_FREE=1 "$WT_BIN")"
[[ "$output" == __WT_ALLOC__* ]] || fail "expected alloc directive, got: $output"
[[ "$output" == *$'\tfree-1\t'* ]] || fail "expected alloc directive to include selected slot, got: $output"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_NAME=work-one WT_TEST_ACTION=free WT_ASSERT_NO_ALLOC=1 WT_ASSERT_HAS_FREE=1 WT_ASSERT_HAS_REALLOC=1 "$WT_BIN")"
[[ "$output" == __WT_FREE__* ]] || fail "expected free directive, got: $output"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_NAME=work-one WT_TEST_ACTION=realloc WT_ASSERT_HAS_REALLOC=1 "$WT_BIN")"
[[ "$output" == __WT_REALLOC__* ]] || fail "expected realloc directive, got: $output"

output="$(cd "$REPO" && WT_SHELL_INTEGRATION=1 WT_FZF_COMMAND="$fake_fzf" WT_SELECT_NAME=work-one WT_TEST_ACTION=remove WT_ASSERT_HAS_REMOVE=1 "$WT_BIN")"
[[ "$output" == __WT_REMOVE__* ]] || fail "expected remove directive, got: $output"
