# HOWTO: Mac → sync → dump on NAS → % status

Repo: [github.com/kzielins/usb-disk-imager](https://github.com/kzielins/usb-disk-imager)

**Rule:** every run starts on the **Mac** with `cd` into the clone, then `git pull`, then commands. No exceptions.

## Paths

| Where | Role | Path |
|-------|------|------|
| **Mac only** | clone (`cd` + `git pull`) | `~/src/usb-disk-imager` |
| **NAS only** | sync target / tool tree | `/share/homes/kzielins/ops/usb-disk-imager` |
| **NAS only** | image output | `/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125` |

**Do not** run `cd ~/src/usb-disk-imager` or `git pull` on the NAS — that path and `git` exist on the Mac. On the NAS after sync: `cd /share/homes/kzielins/ops/usb-disk-imager`.

`udi-rsync-run` creates `--remote-dir` with `mkdir -p` (including missing `ops/`), then rsyncs.

Need SSH user **`admin`** (or root) for `/dev/sdc`. `kzielins` → Permission denied.

---

## 0) ALWAYS — Mac: enter repo + update

```bash
cd ~/src/usb-disk-imager
# ↑ change to YOUR Mac clone of github.com/kzielins/usb-disk-imager

git pull origin main
```

If the folder does not exist yet:

```bash
cd ~
git clone https://github.com/kzielins/usb-disk-imager.git
cd usb-disk-imager
git pull origin main
```

Do this **before** every dump / status / rsync below.

---

## 1) From Mac — dry-sync (optional)

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --dry-sync
```

---

## 2) From Mac — start dump

### A) INTERACTIVE wizard (menus like before) — recommended if you want TUI

You **see** disk/dir prompts inside `screen`. Ctrl-A D detaches.

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run --host kznas3-1 --user admin --remote-dir /share/homes/kzielins/ops/usb-disk-imager --approach wizard
```

(One line — paste-safe.)

### B) FIRE-AND-FORGET (NO menus — that is why you saw nothing)

`--execute --yes` skips all TUI. Job runs in detached screen; use `udi-status` / `screen -r` to watch.

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run --host kznas3-1 --user admin --device /dev/sdc --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 --remote-dir /share/homes/kzielins/ops/usb-disk-imager --approach screen-detach --lang pl --execute --yes
```

### C) nohup (also non-interactive)

Same flags as B, `--approach nohup`.

### See / take over existing screen (your current `udi-dump`)

```bash
ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-dump'
```

If “Attached elsewhere”: `screen -d -r udi-dump`.

---

## 3) From Mac — real % status (no screen attach)

`percent = bytes_read_from_/dev/sdc / device_size * 100` (not `.zst` size).

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

---

## 4) Manual on NAS (after Mac sync)

Still start on **Mac**:

```bash
cd ~/src/usb-disk-imager
git pull origin main

ssh admin@kznas3-1 'mkdir -p /share/homes/kzielins/ops/usb-disk-imager'
rsync -avz --delete --exclude .git --exclude '.DS_Store' \
  ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
```

Then on **NAS** (note the path — not `~/src/...`):

```bash
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager
screen -S udi-dump
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
# Ctrl-A D
```

Status — from **Mac** (preferred):

```bash
cd ~/src/usb-disk-imager
git pull origin main
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

Or on **NAS** after sync succeeded:

```bash
cd /share/homes/kzielins/ops/usb-disk-imager
./bin/udi-status --host local \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

---

## Job files

| File | Meaning |
|------|---------|
| `*.img.zst` | compressed image |
| `*.progress` | `read_bytes` / `total_bytes` / `percent` / ETA |
| `.udi-job` | pointer so `--dir` finds the active job |
| `*.manifest.md` | provenance after success |

More session detail: [LONG-RUN-NAS.md](LONG-RUN-NAS.md).
