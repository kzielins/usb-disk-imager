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
    "${HOST:-${SAVED_HOST}}" "${SSH_USER:-${SAVED_USER}}" "${LAST_DEVICE:-${DEVICE:-${SAVED_DEVICE}}}" \
    "${LAST_DEVICE_SIZE:-${SAVED_DEVICE_SIZE}}" "${OUT_DIR:-${SAVED_OUT_DIR}}" "${LANG_CODE:-${SAVED_LANG}}" > "${STATE_FILE}"
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
scan_smart_destinations() {
  local depth="${1:-3}"
  [[ -n "${SAVED_OUT_DIR:-}" ]] && printf "%s|last-run saved target\n" "${SAVED_OUT_DIR}"
  if [[ -n "${HOST:-}" && "${HOST}" != "local" ]]; then
    run_target "DEPTH='${depth}' bash -s" << 'REMOTE_DIRS' 2>/dev/null || true
      for root in /share/CACHEDEV*_DATA /share/MD*_DATA /share/Public /share/Backups /mnt /srv /data; do
        [ -d "$root" ] || continue
        case "$root" in /share/Public|/share/Backups) [ -L "$root" ] && continue ;; esac
        avail=$(df -BG "$root" 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}')
        printf "remote:%s/usb-images|%s|NAS volume root\n" "$root" "${avail:-0}"
        find "$root" -maxdepth "$DEPTH" -type f \( -iname "*.vmdk" -o -iname "*.vhdx" -o -iname "*.vhd" -o -iname "*.qcow2" -o -iname "*.img" -o -iname "*.img.zst" -o -iname "*.img.gz" -o -iname "*.ova" -o -iname "*.iso" \) 2>/dev/null \
          | head -n 120 | while IFS= read -r f; do
              d1=$(dirname "$f"); d0=$(dirname "$d1"); ext="${f##*.}"
              printf "remote:%s|%s|contains .%s (%s)\n" "$d1" "${avail:-0}" "$ext" "$(basename "$d1")"
              [ "$d0" != "/" ] && [ "$d0" != "/share" ] && printf "remote:%s/usb-images|%s|parent of %s (.%s)\n" "$d0" "${avail:-0}" "$(basename "$d1")" "$ext"
            done
      done | awk -F'|' '!seen[$1]++ {print $0}' | head -n 25
REMOTE_DIRS
  fi
  for lroot in "${HOME}/Backups" "/Volumes" "/mnt" "/media"; do
    [[ -d "${lroot}" ]] || continue
    avail_l=$(df -k "${lroot}" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}')
    [[ "${lroot}" == "${HOME}/Backups" ]] && printf "local:%s/usb-images|%s|Mac/Local backup folder\n" "${lroot}" "${avail_l:-0}"
    find "${lroot}" -maxdepth "${depth}" -type f \( -iname "*.vmdk" -o -iname "*.vhdx" -o -iname "*.img" -o -iname "*.img.zst" -o -iname "*.ova" -o -iname "*.iso" \) 2>/dev/null \
      | grep -v '/Volumes/Macintosh HD' | head -n 40 | while IFS= read -r lf; do
          ld1=$(dirname "$lf"); ld0=$(dirname "$ld1"); lext="${lf##*.}"
          printf "local:%s|%s|local .%s folder\n" "$ld1" "${avail_l:-0}" "$lext"
          [[ "$ld0" != "/" && "$ld0" != "${HOME}" ]] && printf "local:%s/usb-images|%s|parent of %s\n" "$ld0" "${avail_l:-0}" "$(basename "$ld1")"
        done
  done | awk -F'|' '!seen[$1]++ {print $0}'
}
