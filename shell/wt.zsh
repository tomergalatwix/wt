# Shell integration for wt.
#
# The wt binary cannot change the current shell directory by itself, so this
# wrapper handles `wt`, `wt go`, and `wt go -` actions that need `cd`.
wt() {
  if [[ $# -eq 0 ]]; then
    local _wt_result _wt_action _wt_payload _wt_name _wt_path _wt_answer
    _wt_result="$(command wt)" || return $?
    [[ -n "$_wt_result" ]] || return 0

    _wt_action="${_wt_result%%$'\t'*}"
    _wt_payload="${_wt_result#*$'\t'}"

    case "$_wt_action" in
      __WT_GO__)
        cd "$_wt_payload" || return $?
        return 0
        ;;
      __WT_RELEASE__)
        _wt_name="${_wt_payload%%$'\t'*}"
        _wt_path="${_wt_payload#*$'\t'}"
        read -r "?Release ${_wt_name} (${_wt_path})? [y/N] " _wt_answer
        if [[ "$_wt_answer" == [yY] || "$_wt_answer" == [yY][eE][sS] ]]; then
          command wt release "$_wt_path"
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
      __WT_CREATE__)
        local _wt_create_output _wt_create_last _wt_create_path
        _wt_create_output="$(WT_SHELL_INTEGRATION=1 command wt create)" || return $?
        _wt_create_last="${_wt_create_output##*$'\n'}"
        if [[ "$_wt_create_last" == __WT_CREATED__* ]]; then
          _wt_create_path="${_wt_create_last#*$'\t'}"
          print -r -- "${_wt_create_output%$'\n'"$_wt_create_last"}"
          cd "$_wt_create_path" || return $?
          return 0
        fi
        print -r -- "$_wt_create_output"
        return 0
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

  if [[ "${1:-}" == "create" ]]; then
    local _wt_create_output _wt_create_last _wt_create_path
    _wt_create_output="$(WT_SHELL_INTEGRATION=1 command wt "$@")" || return $?
    _wt_create_last="${_wt_create_output##*$'\n'}"
    if [[ "$_wt_create_last" == __WT_CREATED__* ]]; then
      _wt_create_path="${_wt_create_last#*$'\t'}"
      print -r -- "${_wt_create_output%$'\n'"$_wt_create_last"}"
      cd "$_wt_create_path" || return $?
      return 0
    fi
    print -r -- "$_wt_create_output"
    return 0
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

  command wt "$@"
}
