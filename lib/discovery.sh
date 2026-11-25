#!/usr/bin/env bash
STATE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/usb-disk-imager"
STATE_FILE="${STATE_DIR}/state.env"
load_saved_state() {
  SAVED_HOST=""; SAVED_USER=""; SAVED_DEVICE=""; SAVED_DEVICE_SIZE=""; SAVED_OUT_DIR=""; SAVED_LANG=""
  if [[ -f "${STATE_FILE}" ]]; then source "${STATE_FILE}"; fi
}
save_state() {
  mkdir -p "${STATE_DIR}" && chmod 700 "${STATE_DIR}"
  printf "SAVED_HOST=%q\nSAVED_USER=%q\nSAVED_DEVICE=%q\nSAVED_DEVICE_SIZE=%q\nSAVED_OUT_DIR=%q\nSAVED_LANG=%q\n" \
    "${HOST}" "${SSH_USER}" "${LAST_DEVICE:-${DEVICE}}" "${LAST_DEVICE_SIZE:-}" "${OUT_DIR}" "${LANG_CODE}" > "${STATE_FILE}"
  chmod 600 "${STATE_FILE}"
}
filter_noise_hosts() {
  awk 'NF==0 || /^#/ || /[\*\?\|]/ {next} tolower($0) ~ /(github\.com|gitlab|bitbucket\.org|azure\.com|amazonaws\.com|googleusercontent|iphone|ipad|android|localhost)/ {next} !seen[$0]++ {print $0}'
}
discover_candidate_hosts() {
  {
    [[ -n "${SAVED_HOST:-}" ]] && echo "${SAVED_HOST}"
    [[ -f /etc/config/uLinux.conf ]] && echo "local"
    [[ -f "${HOME}/.ssh/config" ]] && awk '/^[[:space:]]*#/ {next} /^[[:space:]]*[Hh][Oo][Ss][Tt][[:space:]]+/ {for(i=2;i<=NF;i++){if($i~/^#/)break; print $i}}' "${HOME}/.ssh/config"
    [[ -f "${HOME}/.ssh/known_hosts" ]] && awk '/^[[:space:]]*#/ {next} {print $1}' "${HOME}/.ssh/known_hosts" | tr ',' '\n' | sed -E 's/^\[([^]]+)\]:[0-9]+$/\1/' | head -n 30
    command -v tailscale >/dev/null 2>&1 && tailscale status 2>/dev/null | awk 'NR>1 && $2 != "" {print $2}' | head -n 20 || true
    echo "local"
  } | filter_noise_hosts
}
discover_candidate_users() {
  { [[ -n "${SAVED_USER:-}" ]] && echo "${SAVED_USER}"; echo "admin"; [[ -n "${USER:-}" ]] && echo "${USER}"; echo "root"; echo "ubuntu"; } | awk 'NF && !seen[$0]++'
}
discover_destination_dirs() {
  {
    [[ -n "${SAVED_OUT_DIR:-}" ]] && echo "${SAVED_OUT_DIR}"
    echo "${HOME}/Backups/usb-images"
    [[ -d "${HOME}/Backups" ]] && find "${HOME}/Backups" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | sort || true
    for base in /Volumes /mnt /media; do
      [[ -d "${base}" ]] && find "${base}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | grep -v '/Volumes/Macintosh HD' | sed 's|$|/usb-images|' | sort || true
    done
    [[ "${HOST}" == "local" && -d /share ]] && find /share -maxdepth 1 -mindepth 1 \( -type l -o -type d \) 2>/dev/null | grep -E '/share/(Public|Backups|CACHEDEV|MD)' | sed 's|$|/usb-images|' | sort || true
  } | awk 'NF && !seen[$0]++'
}
