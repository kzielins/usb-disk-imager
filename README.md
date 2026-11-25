# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT

Vendor-agnostic, non-destructive CLI/TUI utility for creating compressed, SHA256-verified backups of external USB block devices over SSH (from macOS/Linux operator workstations to QNAP QTS, Synology DSM, TrueNAS, Proxmox, or Linux servers) or locally.

## Where to Install
- **Operator Workstation (macOS / Linux):** `./install.sh --prefix ~/.local` — runs remotely over SSH, scans hosts, detects external USB drives, offers safe USB unmount, compares source vs destination size, and streams verified backups.
- **Directly on NAS / Linux (Cron / Hotplug):** Run with `--host local --all-usb --os-only --auto-unmount --yes --execute`.

## Quick Start
```bash
./tests/run-tests.sh
./bin/usb-disk-imager
./bin/usb-disk-imager --host my-nas --user admin --device /dev/sdc --auto-unmount --execute 
