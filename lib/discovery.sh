#!/usr/bin/env bash
STATE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/usb-disk-imager"
STATE_FILE="${STATE_DIR}/state.env"
load_saved_state() {
  SAVED_HOST=""; SAVED_USER=""; SAVED_DEVICE=""; SAVED_DEVICE_SIZE=""; SAVED_OUT_DIR=""; SAVED_LANG=""
  if [[ -f "${STATE_FILE}" ]]; then source "${STATE_FILE}"; fi
  SAVED_HOST="${SAVED_HOST%% *}"
  SAVED_USER="${SAVED_USER%% *}"
  SAVED_DEVICE="${SAVED_DEVICE%% *}"
  SAVED_OUT_DIR="${SAVED_OUT_DIR%% *}"
}
save_state() {
  mkdir -p "${STATE_DIR}" && chmod 700 "${STATE_DIR}"
  local ch="${HOST:-${SAVED_HOST}}"; ch="${ch%% *}"
  local cu="${SSH_USER:-${SAVED_USER}}"; cu="${cu%% *}"
  local cdv="${LAST_DEVICE:-${DEVICE:-${SAVED_DEVICE}}}"; cdv="${cdv%% *}"
  local cod="${OUT_DIR:-${SAVED_OUT_DIR}}"; cod="${cod%% *}"
  printf "SAVED_HOST=%q\nSAVED_USER=%q\nSAVED_DEVICE=%q\nSAVED_DEVICE_SIZE=%q\nSAVED_OUT_DIR=%q\nSAVED_LANG=%q\n" \
    "${ch}" "${cu}" "${cdv}" "${LAST_DEVICE_SIZE:-${SAVED_DEVICE_SIZE}}" "${cod}" "${LANG_CODE:-${SAVED_LANG}}" > "${STATE_FILE}"
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
  local depth="${1:-4}"
  {
    if [[ -n "${SAVED_OUT_DIR:-}" ]]; then
      local sp="${SAVED_OUT_DIR#local:}"; sp="${sp#remote:}"
      if [[ "${SAVED_OUT_DIR}" == remote:* && -n "${HOST:-}" && "${HOST}" != "local" ]]; then
        sfree=$(run_target "p='${sp}'; while [ ! -d \"\$p\" ] && [ \"\$p\" != '/' ]; do p=\$(dirname \"\$p\"); done; df -Pk \"\$p\" 2>/dev/null | awk 'END {if (NF>=6) print int(\$(NF-2)/1024/1024); else print 0}'" || echo 0)
        printf "1|%s|%s|last-run\n" "${SAVED_OUT_DIR}" "${sfree:-0}"
      else
        local lp="${sp}"; while [[ ! -d "${lp}" && "${lp}" != "/" ]]; do lp="$(dirname "${lp}")"; done
        sfree=$(df -Pk "${lp}" 2>/dev/null | awk 'END {if (NF>=6) print int($(NF-2)/1024/1024); else print 0}')
        printf "1|local:%s|%s|last-run\n" "${sp}" "${sfree:-0}"
      fi
    fi
    if [[ -n "${HOST:-}" && "${HOST}" != "local" ]]; then
      run_target "DEPTH='${depth}' bash -s" << 'REMOTE_DIRS' 2>/dev/null || true
        for s in /share/* /srv/* /data/*; do
          [ -d "$s" ] || continue; b=$(basename "$s")
          case "$b" in @*|.*|lost+found|CACHEDEV*_DATA|MD*_DATA|CE_CACHEDEV*|external|Dev*Partition*|HD[A-Z]_DATA|sysvol|Apps|Container|Public) continue ;; esac
          df_line=$(df -Pk "$s/" 2>/dev/null | awk 'END {if (NF>=6) print $1 "|" int($(NF-2)/1024/1024)}')
          fs_dev="${df_line%%|*}"; avail="${df_line##*|}"
          case "$fs_dev" in none|tmpfs|rootfs|/dev/ram*|/dev/md9|/dev/md13) continue ;; esac
          [ "${avail:-0}" -le 0 ] 2>/dev/null && continue
          subs=$(ls -1 "$s/" 2>/dev/null | grep -vE '^(@|\.)' | head -n 4 | tr '\n' ',' | sed 's/,$//')
          printf "2|remote:%s|%s|NAS share%s\n" "$s" "${avail}" "${subs:+: $subs}"
          find "$s/" -maxdepth "$DEPTH" \( -name "@Recycle" -o -name ".@__thumb" -o -name ".qpkg" \) -prune -o \
            -type f \( -iname "*.vmdk" -o -iname "*.vmx" -o -iname "*.vhdx" -o -iname "*.vhd" -o -iname "*.qcow2" -o -iname "*.img" -o -iname "*.img.zst" -o -iname "*.img.gz" -o -iname "*.ova" \) -print 2>/dev/null \
            | head -n 120 | awk -F'/' -v root="$s" '{
                n=NF; d1=""; for(i=2;i<n;i++) d1=d1"/"$i;
                d0=""; for(i=2;i<n-1;i++) d0=d0"/"$i;
                sub_name=$(n-1); file_name=$n;
                # Jeśli plik leży w podfolderze VM (*.vmx / maszyny) wewnątrz repozytorium VM (np. images_vmware/Win10/disk.vmdk), grupuj do katalogu repozytorium d0
                target=d1; item=file_name;
                if (d0 != "" && d0 != "/share" && d0 != root && tolower(d0) ~ /(vmware|vm|images|virtual|backups)/) {
                  target=d0; item=sub_name;
                }
                if (tolower(target) ~ /\/iso$/) next;
                key=target;
                if (!seen_item[key "|" item]++) {
                  cnt[key]++;
                  if (cnt[key] <= 5) items[key] = (items[key] == "" ? item : items[key] ", " item);
                }
              }
              END {
                for (k in cnt) {
                  more = (cnt[k] > 5 ? ", ..." : "");
                  printf "0|remote:%s|%s|%d VMs/IMGs: %s%s\n", k, "'"${avail}"'", cnt[k], items[k], more;
                }
              }'
        done
REMOTE_DIRS
    fi
    for lroot in "${HOME}/Backups" "/Volumes" "/mnt" "/media"; do
      [[ -d "${lroot}" ]] || continue
      avail_l=$(df -Pk "${lroot}" 2>/dev/null | awk 'END {if (NF>=6) print int($(NF-2)/1024/1024); else print 0}')
      [[ "${lroot}" == "${HOME}/Backups" ]] && printf "2|local:%s|%s|Mac local\n" "${lroot}" "${avail_l:-0}"
      find "${lroot}" -maxdepth "${depth}" -type f \( -iname "*.vmdk" -o -iname "*.vmx" -o -iname "*.vhdx" -o -iname "*.img" -o -iname "*.img.zst" -o -iname "*.ova" \) 2>/dev/null \
        | grep -v '/Volumes/Macintosh HD' | head -n 40 | while IFS= read -r lf; do
            ld1=$(dirname "$lf"); lfn=$(basename "$lf")
            printf "0|local:%s|%s|1 VM/IMG: %s\n" "$ld1" "${avail_l:-0}" "$lfn"
          done
    done
  } | awk -F'|' 'NF>=4 && !seen[$2]++ {print $0}' | sort -t'|' -k1,1n -k3,3nr | cut -d'|' -f2- | head -n 25
}
