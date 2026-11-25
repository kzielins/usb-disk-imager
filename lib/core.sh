#!/usr/bin/env bash
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/usb-disk-imager"
LOG_FILE="${LOG_DIR}/runs.log"
log_msg() {
  local line; line=$(printf "[%s] [%s] %s" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${*:2}")
  echo "${line}"; mkdir -p "${LOG_DIR}" 2>/dev/null || true; echo "${line}" >> "${LOG_FILE}" 2>/dev/null || true
}
log_info() { log_msg "INFO" "$@"; }
log_warn() { log_msg "WARN" "$@" >&2; }
log_err()  { log_msg "ERROR" "$@" >&2; }
sha256_stream() { command -v shasum >/dev/null 2>&1 && shasum -a 256 || sha256sum; }
run_target() {
  if [[ "${HOST}" == "local" ]]; then bash -c "$1"; else ssh -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 "${SSH_USER}@${HOST}" "$1"; fi
}
discover_block_devices() {
  run_target "USB_ONLY='${1:-0}' bash -s" << 'REMOTE_SCAN'
    for d in /sys/block/sd* /sys/block/nvme*; do
      [ -e "$d" ] || continue
      dev=$(basename "$d"); sectors=$(cat "$d/size" 2>/dev/null || echo 0); gb=$((sectors * 512 / 1024 / 1024 / 1024))
      model=$(cat "$d/device/model" 2>/dev/null | tr -s ' ' | sed 's/ $//' || echo "unknown")
      rem=$(cat "$d/removable" 2>/dev/null || echo 0); sys_link=$(ls -ld "$d" 2>/dev/null || true); bus="internal"
      if echo "$sys_link" | grep -qi "/usb"; then bus="usb"
      elif [ "$rem" = "1" ] && ! echo "$model" | grep -qi "USB DISK MODULE"; then bus="usb"; fi
      [ "${USB_ONLY}" = "1" ] && [ "${bus}" != "usb" ] && continue
      flags=""
      echo "$model" | grep -qi "USB DISK MODULE" && flags="[INTERNAL-DOM-BLOCKED]"
      grep -Eq "(^|[[:space:]])${dev}(p?[0-9]+)?(\[|[[:space:]]|$)" /proc/mdstat 2>/dev/null && flags="${flags}[RAID-BLOCKED]"
      mount | grep -Eq "^/dev/${dev}(p?[0-9]+)?[[:space:]]" && flags="${flags}[MOUNTED]"
      [ "${bus}" = "usb" ] && [ -z "$(echo "$flags" | grep BLOCKED)" ] && flags="${flags}[RECOMMENDED-USB]"
      printf "/dev/%s | %sGB | %s | %s %s\n" "${dev}" "${gb}" "${bus}" "${model}" "${flags}"
    done
REMOTE_SCAN
}
detect_os_on_device() {
  run_target "DEV='$1' bash -s" << 'REMOTE_OS'
    dev_base=$(basename "$DEV"); found=""
    for part in /dev/${dev_base}[0-9]* /dev/${dev_base}p[0-9]*; do
      [ -b "$part" ] || continue; mnt="/tmp/usb-os-probe-$$-$(basename "$part")"; mkdir -p "$mnt"
      if mount -o ro,noexec,nosuid,nodev "$part" "$mnt" 2>/dev/null; then
        [ -d "$mnt/Windows/System32" ] && found="${found}Windows($part) "
        [ -f "$mnt/EFI/Microsoft/Boot/bootmgfw.efi" ] && found="${found}Windows-EFI($part) "
        [ -f "$mnt/etc/os-release" ] && found="${found}Linux($part) "
        [ -d "$mnt/System/Library/CoreServices" ] && found="${found}macOS($part) "
        umount "$mnt" 2>/dev/null || true
      fi
      rmdir "$mnt" 2>/dev/null || true
    done
    echo "$found"
REMOTE_OS
}
stream_raw_image() {
  local device="$1" img_file="$2" sha_file="$3" compressor="$4" base; base="$(basename "${img_file}")"
  if [[ "${compressor}" == "zstd" ]]; then
    run_target "dd if='${device}' bs=4M status=none" | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") | zstd -T0 -3 -o "${img_file}"
  else
    run_target "dd if='${device}' bs=4M status=none" | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") | gzip -6 > "${img_file}"
  fi
}
stream_filtered_archive() {
  local device="$1" arc_file="$2" sha_file="$3" compressor="$4" max_size="$5" exclude_pat="$6" base; base="$(basename "${arc_file}")"
  run_target "DEV='${device}' MAX_SZ='${max_size}' EXCL='${exclude_pat}' bash -s" << 'REMOTE_TAR' \
    | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") \
    | { [[ "${compressor}" == "zstd" ]] && zstd -T0 -3 -o "${arc_file}" || gzip -6 > "${arc_file}"; }
    dev_base=$(basename "$DEV"); root_mnt="/tmp/usb-ro-arc-$$"; mkdir -p "$root_mnt"
    cleanup() { for sub in "$root_mnt"/*; do umount "$sub" 2>/dev/null || true; rmdir "$sub" 2>/dev/null || true; done; rmdir "$root_mnt" 2>/dev/null || true; }
    trap cleanup EXIT
    for part in /dev/${dev_base}[0-9]* /dev/${dev_base}p[0-9]*; do
      [ -b "$part" ] || continue; sub="$root_mnt/$(basename "$part")"; mkdir -p "$sub"
      mount -o ro,noexec,nosuid,nodev "$part" "$sub" 2>/dev/null || rmdir "$sub" 2>/dev/null || true
    done
    cd "$root_mnt"
    find . -type f $( [ -n "$MAX_SZ" ] && printf -- "-not -size +%s " "$MAX_SZ" ) $( [ -n "$EXCL" ] && printf -- "-not -name %s " "$EXCL" ) -print0 | tar --null -T - -cf -
REMOTE_TAR
}
