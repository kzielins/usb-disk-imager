#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Future post-processing module for splitting Master raw images into:
#   1) user-data-only.tar.zst
#   2) clean-os-only.img.zst (hiberfil/pagefile/user profiles stripped + zero-filled)
# Requires Linux root privileges (losetup --partscan, mount -o rw, dd zero-fill).

slim_check_prerequisites() {
  for cmd in losetup zstd dd mount umount; do
    command -v "${cmd}" >/dev/null 2>&1 || { echo "Missing required tool: ${cmd}" >&2; return 1; }
  done
}
