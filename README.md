# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT | **Version:** 2.2.4

Vendor-agnostic, non-destructive CLI/TUI utility for creating compressed, SHA256-verified backups of external USB block devices over SSH (from macOS/Linux operator workstations to QNAP QTS, Synology DSM, TrueNAS, Proxmox, or Linux servers) or locally.

## Where to Install
- **Operator Workstation (macOS / Linux):** `./install.sh --prefix ~/.local` — runs remotely over SSH, scans hosts, detects external USB drives, offers safe USB unmount, compares source vs destination size, and streams verified backups.
- **Directly on NAS / Linux (Cron / Hotplug / long jobs):** Run with `--host local … --execute` inside `screen` / `tmux` / `nohup`. See **[docs/LONG-RUN-NAS.md](docs/LONG-RUN-NAS.md)**.

## Quick Start
```bash
./tests/run-tests.sh
./bin/usb-disk-imager
./bin/usb-disk-imager --host my-nas --user admin --device /dev/sdc --auto-unmount --execute
```

## Long dumps (hours) — use NAS session + % progress

Laptop SSH alone often dies (`Broken pipe` / timeout). On QNAP:

```bash
ssh admin@my-nas
export TERM=vt100          # fixes: screen: $TERM too long - sorry.
cd /path/to/usb-disk-imager
screen -S udi-sdc
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/USER/images_vmware/job \
  --mode raw --yes --execute
# Ctrl-A D  → detach;  TERM=vt100 screen -r udi-sdc  → reattach
```

Progress without attach (sibling `*.progress` file, percent = bytes read from disk):

```bash
./bin/udi-watch-progress --host my-nas --user admin \
  --file /share/homes/USER/images_vmware/job/NAME.img.zst
```

Full how-to (screen / tmux / nohup / monitor): **[docs/LONG-RUN-NAS.md](docs/LONG-RUN-NAS.md)**.

## Notes
- Raw device read usually needs **`admin`/`root`** — unprivileged users get `Permission denied` on `/dev/sdX`.
- Default mode is dry-run; `--execute` writes image + SHA256 + provenance manifest.
- Slimming / OS vs user-data post-process: [docs/IMAGE-SLIMMING.md](docs/IMAGE-SLIMMING.md).
