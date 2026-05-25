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
          command wt release "$_wt_name"
        fi
        return $?
        ;;
      __WT_CREATE__)
        command wt create
        return $?
        ;;
      *)
        print -r -- "$_wt_result"
        return 0
        ;;
    esac
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
