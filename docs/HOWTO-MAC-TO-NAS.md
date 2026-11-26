# HOWTO: Mac → sync repo → run dump on NAS → check %

This is the **operator entry**. Repo: [usb-disk-imager](https://github.com/kzielins/usb-disk-imager).

## Directories (remember these)

| Role | Path |
|------|------|
| Mac checkout (you edit / pull git here) | wherever you cloned, e.g. `~/src/usb-disk-imager` |
| **Sync target on NAS** (rsync destination) | `/share/homes/kzielins/ops/usb-disk-imager` |
| **cd on NAS** after sync | `cd /share/homes/kzielins/ops/usb-disk-imager` |
| Image output folder | `/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125` |

`udi-rsync-run` copies the Mac checkout → sync target, then starts the job **on the NAS** with `--host local` so the Mac can sleep.

Need **`admin`** (or root) to read `/dev/sdc`. User `kzielins` → Permission denied.

## A) From the Mac (recommended) — one script, 3 approaches

```bash
cd ~/src/usb-disk-imager   # your Mac clone
git pull

# optional: only show what rsync would copy
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --dry-sync
```

### Approach 1 — detached `screen` on NAS

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-detach --lang pl --execute --yes
```

Reattach later: `ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-dump'`

### Approach 2 — `nohup` (no screen)

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach nohup --lang pl --execute --yes
```

### Approach 3 — interactive screen (then Ctrl-A D)

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-attach --lang pl --execute --yes
```

## B) Status / real percent (from Mac, no attach)

Percent is **not** the size of `.img.zst`. It is:

`percent = bytes_read_from_/dev/sdc / device_size_bytes * 100`

```bash
# Auto-find latest job in the output folder
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

Example board:

```text
Progress:  [########----------------------]  24%
Read:      115.0 / 476.8 GiB
Planned:   476.8 GiB  ← full block device size
Done:      115.0 GiB  ← bytes read from device so far
Out file:  43.5 GiB compressed (NOT used for %)
ETA:       1h12m
Formula:   percent = read_bytes / total_bytes * 100
```

One-shot (no loop): omit `--watch`.

## C) Manual: SSH to NAS, cd into synced tree

```bash
# Mac → sync only
rsync -avz --delete \
  --exclude .git --exclude '.DS_Store' \
  ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/

ssh admin@kznas3-1
export TERM=vt100    # fixes: screen: $TERM too long - sorry.
cd /share/homes/kzielins/ops/usb-disk-imager
screen -S udi-dump
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
# Ctrl-A D
```

On NAS, status without screen:

```bash
cd /share/homes/kzielins/ops/usb-disk-imager
./bin/udi-status --host local \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

## Files the job writes

| File | Meaning |
|------|---------|
| `*.img.zst` | compressed image |
| `*.img.zst.sha256` | checksum |
| `*.img.zst.progress` | key=value status (`read_bytes`, `total_bytes`, `percent`, `eta_seconds`) |
| `.udi-job` | pointer to active image/progress (so `--dir` works) |
| `*.manifest.md` | provenance after success |

## See also

- [LONG-RUN-NAS.md](LONG-RUN-NAS.md) — screen / tmux / nohup details
- [IMAGE-SLIMMING.md](IMAGE-SLIMMING.md) — post-process after the dump
