#!/usr/bin/env bash
tui_select() {
  local prompt="$1"; shift; local items=("$@") count=${#items[@]} selected=0 key="" seq=""
  [[ ! -t 0 || ! -w /dev/tty ]] && { echo "${items[0]:-}"; return 0; }
  printf "\033[1m%s\033[0m\n\033[?25l" "${prompt}" >/dev/tty
  trap 'printf "\033[?25h" >/dev/tty' RETURN
  while true; do
    for ((i = 0; i < count; i++)); do
      [[ "${i}" -eq "${selected}" ]] && printf "  \033[1;31m❯ %s\033[0m\033[K\n" "${items[$i]}" >/dev/tty || printf "    %s\033[K\n" "${items[$i]}" >/dev/tty
    done
    IFS= read -rsn1 key </dev/tty
    if [[ "${key}" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 1 seq </dev/tty || true
      [[ "${seq}" == "[A" ]] && selected=$(( (selected - 1 + count) % count ))
      [[ "${seq}" == "[B" ]] && selected=$(( (selected + 1) % count ))
    elif [[ "${key}" == "k" || "${key}" == "K" ]]; then selected=$(( (selected - 1 + count) % count ))
    elif [[ "${key}" == "j" || "${key}" == "J" ]]; then selected=$(( (selected + 1) % count ))
    elif [[ "${key}" == "" ]]; then printf "\033[?25h" >/dev/tty; echo "${items[$selected]}"; return 0; fi
    printf "\033[%dA" "${count}" >/dev/tty
  done
}
