# HOWTO: Mac → sync → dump on NAS → % status

Repo: [github.com/kzielins/usb-disk-imager](https://github.com/kzielins/usb-disk-imager)

**Rule:** every run starts on the **Mac** with `cd` into the clone, then `git pull`, then commands. No exceptions.

## Paths

| Role | Path |
|------|------|
| Mac clone (`cd` here first) | wherever you cloned this repo (example: `~/src/usb-disk-imager`) |
| NAS sync target (`--remote-dir`) | `/share/homes/kzielins/ops/usb-disk-imager` |
| NAS `cd` after sync | `/share/homes/kzielins/ops/usb-disk-imager` |
| Image output | `/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125` |

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

## 2) From Mac — start dump (3 approaches)

Each block is full copy-paste: `cd` → `git pull` → run.

### Approach 1 — detached `screen` on NAS (recommended)

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-detach --lang pl --execute --yes
```

Reattach later:

```bash
ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-dump'
```

### Approach 2 — `nohup`

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach nohup --lang pl --execute --yes
```

### Approach 3 — interactive `screen` (Ctrl-A D to detach)

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-attach --lang pl --execute --yes
```

What `udi-rsync-run` does: rsync Mac clone → `/share/homes/kzielins/ops/usb-disk-imager`, then on NAS runs `./bin/usb-disk-imager --host local …` inside screen/nohup.

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

Still start on Mac:

```bash
cd ~/src/usb-disk-imager
git pull origin main

rsync -avz --delete --exclude .git --exclude '.DS_Store' \
  ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
```

Then NAS:

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

Status on NAS:

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
