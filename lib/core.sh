#!/usr/bin/env bash
LOG_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/usb-disk-imager"
LOG_FILE="${LOG_DIR}/runs.log"
TRACE_FILE="${LOG_DIR}/trace.log"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

if [[ -w "${LOG_DIR}" ]]; then
  exec 9>>"${TRACE_FILE}"
  export BASH_XTRACEFD=9
  PS4='+ [${EPOCHSECONDS:-$(date +%s)}] ${BASH_SOURCE##*/}:${LINENO}: '
  set -x
fi

_log_write() {
  local lvl="$1" caller_info="$2"; shift 2
  local line
  line=$(printf "[%s] [%-5s] [%s] %s" "$(date -u +\%Y-\%m-\%dT\%H:\%M:\%SZ)" "${lvl}" "${caller_info}" "$*")
  echo "${line}" >> "${LOG_FILE}" 2>/dev/null || true
  [[ "${lvl}" != "DEBUG" && "${lvl}" != "CMD" ]] && echo "${line}"
  return 0
}
log_debug() { _log_write "DEBUG" "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" "$@"; }
log_info()  { _log_write "INFO"  "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" "$@"; }
log_warn()  { _log_write "WARN"  "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" "$@" >&2; }
log_err()   { _log_write "ERROR" "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}" "$@" >&2; }
trap 'rc=$?; _log_write "ERROR" "${BASH_SOURCE[0]##*/}:${LINENO}" "TRAP_ERR rc=${rc} cmd=${BASH_COMMAND}" >&2' ERR
sha256_stream() { command -v shasum >/dev/null 2>&1 && shasum -a 256 || sha256sum; }
run_target() {
  local cmd="$1" out="" err_file rc=0
  err_file=$(mktemp /tmp/udi-ssh-err.XXXXXX)
  if [[ "${HOST}" == "local" ]]; then
    _log_write "CMD" "run_target:local" "bash -c ${cmd}"
    out=$(bash -c "${cmd}" 2>"${err_file}") || rc=$?
  else
    _log_write "CMD" "run_target:${SSH_USER}@${HOST}" "ssh ${SSH_USER}@${HOST} -- ${cmd}"
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 "${SSH_USER}@${HOST}" "${cmd}" 2>"${err_file}") || rc=$?
  fi
  if [[ -s "${err_file}" ]]; then
    _log_write "STDERR" "run_target:rc=${rc}" "$(tr '\n' ' ' < "${err_file}")"
  fi
  _log_write "DEBUG" "run_target" "rc=${rc} output_bytes=${#out}"
  rm -f "${err_file}"
  printf "%s" "${out}"
  return "${rc}"
}
get_device_bytes() {
  local dev_base; dev_base="$(basename "$1")"
  run_target "if [ -r /sys/block/${dev_base}/size ]; then echo \$(( \$(cat /sys/block/${dev_base}/size) * 512 )); else /sbin/blockdev --getsize64 '$1' 2>/dev/null || echo 0; fi"
}
discover_block_devices() {
  run_target "USB_ONLY='${1:-0}' bash -s" << 'REMOTE_SCAN'
    for d in /sys/block/sd* /sys/block/nvme*; do
      [ -e "$d" ] || continue
      dev=$(basename "$d"); sectors=$(cat "$d/size" 2>/dev/null || echo 0); gb=$((sectors * 512 / 1024 / 1024 / 1024))
      model=$(cat "$d/device/model" 2>/dev/null | tr -s ' ' | sed 's/ $//' || echo "unknown")
      rem=$(cat "$d/removable" 2>/dev/null || echo 0)
      real_sys=$(readlink -f "$d" 2>/dev/null || ls -ld "$d" 2>/dev/null || true); bus="internal"
      if echo "$real_sys" | grep -qiE "usb|xhci|ehci|ohci|uhci"; then bus="usb"
      elif [ "$rem" = "1" ] && ! echo "$model" | grep -qi "USB DISK MODULE"; then bus="usb"
      elif echo "$model" | grep -qiE "RTL9210|JMS58|ASM236|ASM115|UASP"; then bus="usb"; fi
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
  if [[ "${img_file}" == remote:* ]]; then
    local rpath="${img_file#remote:}"
    run_target "mkdir -p '$(dirname "${rpath}")' && if command -v zstd >/dev/null 2>&1 && [ '${compressor}' = 'zstd' ]; then dd if='${device}' bs=4M status=none | tee >(sha256sum | awk -v f='${base}' '{print \$1 \"  \" f}' > '${rpath}.sha256') | zstd -T0 -3 -o '${rpath}'; else dd if='${device}' bs=4M status=none | tee >(sha256sum | awk -v f='${base}' '{print \$1 \"  \" f}' > '${rpath}.sha256') | gzip -6 > '${rpath}'; fi"
  elif [[ "${compressor}" == "zstd" ]]; then
    run_target "dd if='${device}' bs=4M status=none" | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") | zstd -T0 -3 -o "${img_file}"
  else
    run_target "dd if='${device}' bs=4M status=none" | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") | gzip -6 > "${img_file}"
  fi
}
stream_filtered_archive() {
  local device="$1" arc_file="$2" sha_file="$3" compressor="$4" max_size="$5" exclude_pat="$6" base; base="$(basename "${arc_file}")"
  local local_out="${arc_file#local:}"
  run_target "DEV='${device}' MAX_SZ='${max_size}' EXCL='${exclude_pat}' bash -s" << 'REMOTE_TAR' \
    | tee >(sha256_stream | awk -v f="${base}" '{print $1 "  " f}' > "${sha_file}") \
    | { [[ "${compressor}" == "zstd" ]] && zstd -T0 -3 -o "${local_out}" || gzip -6 > "${local_out}"; }
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

write_provenance_manifest() {
  local target_dev="$1" dev_gb="$2" dev_bytes="$3" img_file="$4" sha_file="$5" mode="$6" compressor="$7" out_dir="$8"
  local dev_base; dev_base="$(basename "${target_dev}")"
  local ts_iso; ts_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local probe_info
  probe_info=$(run_target "DEV='${target_dev}' B='${dev_base}' bash -s" << 'REMOTE_META' 2>/dev/null || echo "probe_unavailable"
    echo "=== HOSTNAME ==="
    hostname -f 2>/dev/null || hostname
    echo "=== KERNEL ==="
    uname -a
    echo "=== SYSFS_DEVICE ==="
    echo "model=$(cat /sys/block/${B}/device/model 2>/dev/null | tr -s ' ')"
    echo "vendor=$(cat /sys/block/${B}/device/vendor 2>/dev/null | tr -s ' ')"
    echo "serial=$(cat /sys/block/${B}/device/serial 2>/dev/null || udevadm info --query=property --name=${DEV} 2>/dev/null | grep -E 'ID_SERIAL|ID_MODEL|ID_FS' | tr '\n' ';')"
    echo "sys_path=$(readlink -f /sys/block/${B} 2>/dev/null)"
    echo "=== PARTITIONS ==="
    fdisk -l "${DEV}" 2>/dev/null || parted -s "${DEV}" print 2>/dev/null || cat /proc/partitions | grep -E "${B}"
    echo "=== BLKID ==="
    blkid ${DEV}* 2>/dev/null || true
REMOTE_META
  )
  local os_sig; os_sig="$(detect_os_on_device "${target_dev}" || true)"
  local sha_val="DRY-RUN-NOT-WRITTEN"
  if [[ "${img_file}" == remote:* ]]; then
    local rsha="${img_file#remote:}.sha256"
    sha_val=$(run_target "awk '{print \$1}' '${rsha}' 2>/dev/null || echo pending" || echo "pending")
  elif [[ -f "${sha_file}" ]]; then
    sha_val=$(awk '{print $1}' "${sha_file}")
  fi

  local md_body
  md_body=$(cat << MANIFEST_MD
# Disk / VM Image Provenance Manifest

- **Created (UTC):** \`${ts_iso}\`
- **Tool:** \`universal-usb-disk-imager v${VERSION:-2.2.3}\`
- **Source Host:** \`${SSH_USER}@${HOST}\`
- **Source Block Device:** \`${target_dev}\` (${dev_gb} GB / ${dev_bytes} bytes)
- **Detected OS Signatures:** \`${os_sig:-none detected}\`
- **Imaging Mode:** \`${mode}\` (compressor: \`${compressor}\`)
- **Destination Folder:** \`${out_dir}\`
- **Image Artifact:** \`${img_file}\`
- **SHA256 Checksum:** \`${sha_val}\`

## Hardware & Partition Inspection

\`\`\`text
${probe_info}
\`\`\`
MANIFEST_MD
)
  if [[ "${img_file}" == remote:* ]]; then
    local rbase="${img_file#remote:}"
    printf "%s\n" "${md_body}" | run_target "cat > '${rbase}.manifest.md'"
  else
    local lbase="${img_file#local:}"
    printf "%s\n" "${md_body}" > "${lbase}.manifest.md"
  fi
  log_info "Provenance manifest written: ${img_file}.manifest.md"
}
