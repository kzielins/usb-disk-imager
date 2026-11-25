#!/usr/bin/env bash
tui_select() {
  local prompt="$1"; shift; local options=("$@"); local count=${#options[@]}
  [[ "${count}" -eq 0 ]] && return 1
  if [[ ! -t 0 ]] || ! [[ -r /dev/tty && -w /dev/tty ]]; then
    echo "${prompt}" >&2; local i=1
    for opt in "${options[@]}"; do echo "  ${i}) ${opt}" >&2; i=$((i+1)); done
    read -rp "#? " idx </dev/tty
    if [[ "${idx}" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= count )); then echo "${options[$((idx-1))]}"; return 0; fi
    return 1
  fi
  local selected=0 key seq cols max_w line_txt
  cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
  [[ -z "${cols}" || "${cols}" -eq 0 ]] && cols=$(tput cols </dev/tty 2>/dev/null || echo 160)
  max_w=$((cols - 5)); (( max_w < 60 )) && max_w=60
  printf "\033[?25l" >/dev/tty
  trap 'printf "\033[?25h" >/dev/tty' RETURN
  printf "\033[1;36m%s\033[0m\n" "${prompt}" >/dev/tty
  while true; do
    for ((i=0; i<count; i++)); do
      line_txt="${options[$i]}"
      if (( ${#line_txt} > max_w )); then line_txt="${line_txt:0:$((max_w-3))}..."; fi
      if (( i == selected )); then
        if [[ "${options[$i]}" == *"TOO SMALL"* || "${options[$i]}" == *"BLOCKED"* ]]; then
          printf "\r\033[2K  \033[1;31m❯ %s\033[0m\n" "${line_txt}" >/dev/tty
        else
          printf "\r\033[2K  \033[1;32m❯ %s\033[0m\n" "${line_txt}" >/dev/tty
        fi
      else
        if [[ "${options[$i]}" == *"TOO SMALL"* || "${options[$i]}" == *"BLOCKED"* ]]; then
          printf "\r\033[2K    \033[0;31m%s\033[0m\n" "${line_txt}" >/dev/tty
        elif [[ "${options[$i]}" == *"[VMware"* || "${options[$i]}" == *"[RECOMMENDED"* ]]; then
          printf "\r\033[2K    \033[0;36m%s\033[0m\n" "${line_txt}" >/dev/tty
        else
          printf "\r\033[2K    %s\n" "${line_txt}" >/dev/tty
        fi
      fi
    done
    IFS= read -rsn1 key </dev/tty
    if [[ "${key}" == $'\x1b' ]]; then
      IFS= read -rsn2 -t 0.1 seq </dev/tty || true
      case "${seq}" in
        "[A") selected=$(( (selected - 1 + count) % count )) ;;
        "[B") selected=$(( (selected + 1) % count )) ;;
      esac
    elif [[ "${key}" == "" ]]; then
      printf "\033[?25h" >/dev/tty
      echo "${options[$selected]}"
      return 0
    fi
    printf "\033[%dA" "${count}" >/dev/tty
  done
}
