#!/usr/bin/env bash
validate_device_syntax() { [[ "$1" =~ ^/dev/(sd[a-z]+|nvme[0-9]+n[0-9]+|disk[0-9]+)$ ]]; }
check_device_exists() { [[ "$(run_target "test -b '$1' && echo yes || echo no")" == "yes" ]]; }
check_not_system_disk() {
  local dev_base="$1" md="${2-__UNSET__}" mod="${3-__UNSET__}"
  [[ "${md}" == "__UNSET__" ]] && md=$(run_target "cat /proc/mdstat 2>/dev/null || true")
  [[ "${mod}" == "__UNSET__" ]] && mod=$(run_target "cat /sys/block/${dev_base}/device/model 2>/dev/null || true")
  echo "${mod}" | grep -qi "USB DISK MODULE" && return 1
  echo "${md}" | grep -Eq "(^|[[:space:]])${dev_base}(p?[0-9]+)?(\[|[[:space:]]|$)" && return 1
  return 0
}
check_not_mounted() {
  local dev="$1" mnt="${2-__UNSET__}"
  [[ "${mnt}" == "__UNSET__" ]] && mnt=$(run_target "mount 2>/dev/null || true")
  echo "${mnt}" | grep -Eq "^${dev}(p?[0-9]+)?[[:space:]]" && return 1
  return 0
}
safe_unmount_usb_device() {
  local dev="$1" dev_base="$2" bus="$3" gb="$4"
  check_not_system_disk "${dev_base}" || { log_err "REFUSED UNMOUNT: ${dev} is RAID or internal DOM!"; return 1; }
  [[ "${bus}" != "usb" ]] && { log_err "REFUSED UNMOUNT: ${dev} is not USB (bus=${bus})."; return 1; }
  (( gb > 4096 )) && { log_err "REFUSED UNMOUNT: ${dev} is ${gb}GB (>4TB). Refusing unmount on large volume."; return 1; }
  log_info "Unmounting external USB partitions on ${dev}..."
  run_target "for p in ${dev}[0-9]* ${dev}p[0-9]*; do [ -b \"\$p\" ] && umount \"\$p\" 2>/dev/null || true; done"
  check_not_mounted "${dev}"
}
