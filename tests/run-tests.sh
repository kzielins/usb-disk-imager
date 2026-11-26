#!/usr/bin/env bash
set -euo pipefail
export XDG_STATE_HOME="$(mktemp -d)" XDG_CONFIG_HOME="$(mktemp -d)"
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; BIN="${PKG_DIR}/bin/usb-disk-imager"
log_info() { :; }; log_err() { :; }; run_target() { echo ""; }
echo "[1/7] Version & help..."
"${BIN}" --version | grep >/dev/null "2.2.5"
"${BIN}" --help | grep >/dev/null "usb-disk-imager"
test -x "${PKG_DIR}/bin/udi-status"
"${PKG_DIR}/bin/udi-status" --help | grep >/dev/null "read_bytes"
test -x "${PKG_DIR}/bin/udi-rsync-run"
"${PKG_DIR}/bin/udi-rsync-run" --help | grep >/dev/null "screen-detach"
test -f "${PKG_DIR}/lib/image-pipeline.sh"
test -f "${PKG_DIR}/docs/HOWTO-MAC-TO-NAS.md"
grep -q "git pull origin main" "${PKG_DIR}/docs/HOWTO-MAC-TO-NAS.md"
grep -q "cd ~/src/usb-disk-imager" "${PKG_DIR}/docs/HOWTO-MAC-TO-NAS.md"
grep -q "git pull origin main" "${PKG_DIR}/README.md"
grep -q 'mkdir -p' "${PKG_DIR}/bin/udi-rsync-run"
grep -q "Do not" "${PKG_DIR}/docs/HOWTO-MAC-TO-NAS.md"
# udi-status: parse synthetic progress (real % formula)
TMPJ=$(mktemp -d)
cat > "${TMPJ}/demo.img.zst.progress" << 'P'
# usb-disk-imager progress v1
updated_utc=2026-01-01T00:00:00Z
stage=imaging
device=/dev/sdc
image=/tmp/demo.img.zst
read_bytes=128849018880
total_bytes=512110190592
percent=25
out_bytes=40000000000
rate_bytes_per_sec=52428800
eta_seconds=7200
started_utc=2026-01-01T00:00:00Z
human=25%
P
echo "progress=${TMPJ}/demo.img.zst.progress" > "${TMPJ}/.udi-job"
OUT=$("${PKG_DIR}/bin/udi-status" --host local --dir "${TMPJ}")
echo "${OUT}" | grep >/dev/null "25%"
echo "${OUT}" | grep >/dev/null "read_bytes / total_bytes"
rm -rf "${TMPJ}"
echo "[2/7] Non-interactive dry-run (EN & PL)..."
"${BIN}" --dry-run </dev/null | grep >/dev/null "INDEPENDENT DRY-RUN"
"${BIN}" --lang pl --dry-run </dev/null | grep >/dev/null "INDEPENDENT DRY-RUN"
echo "[3/7] Noise filter & discovery..."
source "${PKG_DIR}/lib/discovery.sh"
FILTERED=$(printf "# comment\ngithub.com\niphone-15-pro\nnas-box\n" | filter_noise_hosts)
echo "${FILTERED}" | grep >/dev/null -x "nas-box"
echo "[4/7] Device syntax guard..."
source "${PKG_DIR}/lib/guards.sh"
if validate_device_syntax "/dev/sda1"; then exit 1; fi
validate_device_syntax "/dev/sdc"
echo "[5/7] RAID, DOM & safe-unmount guards..."
if check_not_system_disk "sda" "md9 : active raid1 sda1[0] sdb1[1]" ""; then exit 1; fi
if check_not_system_disk "sdc" "" "USB DISK MODULE"; then exit 1; fi
check_not_system_disk "sde" "md9 : active raid1 sda1[0]" "RTL9210B"
if safe_unmount_usb_device "/dev/sda" "sda" "internal" "9314"; then exit 1; fi
echo "[6/7] Mounted partition guard..."
if check_not_mounted "/dev/sde" "/dev/sde1 on /mnt/usb type ext4 (rw)"; then exit 1; fi
check_not_mounted "/dev/sdf" "/dev/sde1 on /mnt/usb type ext4 (rw)"
echo "[7/7] Syntax & zero private host/IP leaks..."
bash -n "${BIN}" "${PKG_DIR}/lib/"*.sh "${PKG_DIR}/i18n/"*.sh "${PKG_DIR}/tests/"*.sh "${PKG_DIR}/install.sh"
if grep -rnE "kznas|192\.168\.|100\.95\." "${PKG_DIR}/bin" "${PKG_DIR}/lib" "${PKG_DIR}/i18n"; then exit 1; fi
echo "ALL 7 TEST SUITES PASSED."
