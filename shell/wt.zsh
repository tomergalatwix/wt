# Shell integration for wt.
#
# The wt binary cannot change the current shell directory by itself, so this
# wrapper handles `wt`, `wt go`, and `wt go -` actions that need `cd`.
__wt_run_and_cd_alloc() {
  local _wt_marker_file _wt_marker _wt_line _wt_status _wt_alloc_path
  _wt_marker_file="$(mktemp -t wt-alloc.XXXXXX)" || return $?

  WT_SHELL_INTEGRATION=1 command wt "$@" | while IFS= read -r _wt_line; do
    if [[ "$_wt_line" == __WT_ALLOCATED__* ]]; then
      print -r -- "$_wt_line" >| "$_wt_marker_file"
    else
      print -r -- "$_wt_line"
    fi
  done
  _wt_status=${pipestatus[1]}

  _wt_marker="$(cat "$_wt_marker_file")"
  rm -f "$_wt_marker_file"
  if [[ "$_wt_status" -ne 0 ]]; then
    return "$_wt_status"
  fi
  if [[ "$_wt_marker" == __WT_ALLOCATED__* ]]; then
    _wt_alloc_path="${_wt_marker#*$'\t'}"
    cd "$_wt_alloc_path" || return $?
  fi
  return 0
}

wt() {
  if [[ $# -eq 0 ]]; then
    local _wt_result _wt_action _wt_payload _wt_name _wt_path _wt_answer
    _wt_result="$(WT_SHELL_INTEGRATION=1 command wt)" || return $?
    [[ -n "$_wt_result" ]] || return 0

    _wt_action="${_wt_result%%$'\t'*}"
    _wt_payload="${_wt_result#*$'\t'}"

    case "$_wt_action" in
      __WT_GO__)
        cd "$_wt_payload" || return $?
        return 0
        ;;
      __WT_FREE__)
        _wt_name="${_wt_payload%%$'\t'*}"
        _wt_path="${_wt_payload#*$'\t'}"
        read -r "?Free ${_wt_name} (${_wt_path})? [y/N] " _wt_answer
        if [[ "$_wt_answer" == [yY] || "$_wt_answer" == [yY][eE][sS] ]]; then
          command wt free "$_wt_path"
        fi
        return $?
        ;;
      __WT_REMOVE__)
        _wt_name="${_wt_payload%%$'\t'*}"
        _wt_path="${_wt_payload#*$'\t'}"
        read -r "?Remove ${_wt_name} (${_wt_path})? This deletes the worktree directory. [y/N] " _wt_answer
        if [[ "$_wt_answer" == [yY] || "$_wt_answer" == [yY][eE][sS] ]]; then
          command wt remove "$_wt_path" --yes
        fi
        return $?
        ;;
      __WT_REALLOC__)
        local _wt_branch
        _wt_name="${_wt_payload%%$'\t'*}"
        _wt_path="${_wt_payload#*$'\t'}"
        read -r "?Branch name: " _wt_branch
        [[ -n "$_wt_branch" ]] || return 0
        print -r -- "Realloc will detach the current branch, move/rename ${_wt_name} into the free pool, then rename it to ${_wt_branch}."
        read -r "?Realloc ${_wt_name} (${_wt_path}) to ${_wt_branch}? [y/N] " _wt_answer
        if [[ "$_wt_answer" == [yY] || "$_wt_answer" == [yY][eE][sS] ]]; then
          __wt_run_and_cd_alloc realloc "$_wt_path" "$_wt_branch" --yes
        fi
        return $?
        ;;
      __WT_ALLOC__)
        __wt_run_and_cd_alloc alloc
        return $?
        ;;
      __WT_GROW__)
        command wt grow
        return $?
        ;;
      *)
        print -r -- "$_wt_result"
        return 0
        ;;
    esac
  fi

  if [[ "${1:-}" == "alloc" ]]; then
    __wt_run_and_cd_alloc "$@"
    return $?
  fi

  if [[ "${1:-}" == "realloc" ]]; then
    __wt_run_and_cd_alloc "$@"
    return $?
  fi

  if [[ "${1:-}" == "go" ]]; then
    shift
    if [[ "${1:-}" == "-" ]]; then
      cd - || return $?
      return 0
    fi
    local _wt_path
    _wt_path="$(command wt go --print-path "$@")" || return $?
    cd "$_wt_path" || return $?
    return 0
  fi

  if [[ "${1:-}" == "update" ]]; then
    command wt "$@" || return $?
    source "${WT_CONFIG_DIR:-$HOME/.config/wt}/wt.zsh"
    return 0
  fi

  command wt "$@"
}
