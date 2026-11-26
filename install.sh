#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Author: Krzysztof Zielinski <https://github.com/kzielins>
set -euo pipefail
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PREFIX="${HOME}/.local"; CRON_SCHEDULE=""; INSTALL_UDEV=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;; --install-cron) CRON_SCHEDULE="$2"; shift 2 ;; --install-udev) INSTALL_UDEV=1; shift ;;
    -h|--help) echo "Usage: ./install.sh [--prefix <dir>] [--install-cron '0 */4 * * *'] [--install-udev]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
TARGET_LIB="${PREFIX}/share/usb-disk-imager"; TARGET_BIN="${PREFIX}/bin"
mkdir -p "${TARGET_LIB}" "${TARGET_BIN}"
cp -R "${SRC_DIR}/bin" "${SRC_DIR}/lib" "${SRC_DIR}/i18n" "${SRC_DIR}/docs" "${TARGET_LIB}/"
chmod +x "${TARGET_LIB}/bin/usb-disk-imager" \
  "${TARGET_LIB}/bin/udi-status" \
  "${TARGET_LIB}/bin/udi-watch-progress" \
  "${TARGET_LIB}/bin/udi-rsync-run" \
  "${TARGET_LIB}/lib/image-pipeline.sh"
ln -sf "${TARGET_LIB}/bin/usb-disk-imager" "${TARGET_BIN}/usb-disk-imager"
ln -sf "${TARGET_LIB}/bin/udi-status" "${TARGET_BIN}/udi-status"
ln -sf "${TARGET_LIB}/bin/udi-watch-progress" "${TARGET_BIN}/udi-watch-progress"
ln -sf "${TARGET_LIB}/bin/udi-rsync-run" "${TARGET_BIN}/udi-rsync-run"
echo "Installed usb-disk-imager + udi-status + udi-rsync-run to ${TARGET_BIN}/"
if [[ -n "${CRON_SCHEDULE}" ]]; then
  CRON_CMD="${CRON_SCHEDULE} ${TARGET_BIN}/usb-disk-imager --host local --all-usb --os-only --auto-unmount --yes --execute >> /tmp/usb-disk-imager-cron.log 2>&1"
  (crontab -l 2>/dev/null | grep -v "usb-disk-imager"; echo "${CRON_CMD}") | crontab -
fi
if [[ "${INSTALL_UDEV}" -eq 1 && -d /etc/udev/rules.d ]]; then
  printf 'ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ENV{DEVTYPE}=="disk", RUN+="%s/usb-disk-imager --host local --device /dev/%%k --os-only --auto-unmount --yes --execute"\n' "${TARGET_BIN}" > /etc/udev/rules.d/99-usb-disk-imager.rules
  udevadm control --reload-rules 2>/dev/null || true
fi
