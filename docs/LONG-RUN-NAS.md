# Long-running USB image dumps — from your Mac via rsync

**Repo:** [github.com/kzielins/usb-disk-imager](https://github.com/kzielins/usb-disk-imager) (not the infra meta-repo).

You work on the **Mac**. The script **rsyncs** this repo to the NAS, then starts the dump **on the NAS** so laptop sleep / Tailscale flaps do not kill a multi-hour job.

Privileged SSH user (`admin` / `root`) is required to read `/dev/sdc`. Plain `kzielins` → `Permission denied`.

## From the Mac: one command (3 approaches)

```bash
cd /path/to/usb-disk-imager   # this checkout on the Mac
```

### Approach 1 — `screen-detach` (recommended)

rsync → start **detached** `screen` on NAS → close the lid.

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-detach --lang pl --execute --yes
```

- Reattach later:  
  `ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-dump'`
- Detach again: `Ctrl-A` then `D`

### Approach 2 — `nohup` (if `screen` missing / TERM broken)

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach nohup --lang pl --execute --yes
```

- Log: `ssh admin@kznas3-1 'tail -f /share/homes/kzielins/images_vmware/.../udi-run.log'`

### Approach 3 — `screen-attach` (watch once, then detach)

rsync → interactive SSH into `screen` (you see output; `Ctrl-A D` leaves it running).

```bash
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-attach --lang pl --execute --yes
```

### Dry-run first (no write, no start — only rsync `-n`)

```bash
./bin/udi-rsync-run ... --dry-sync
# then without --execute for imager dry-run after a real sync:
./bin/udi-rsync-run ... --approach screen-detach   # omit --execute
```

## Progress % without attaching

Sibling file: `<image>.img.zst.progress` — `read=… (N%)` is bytes read from the disk.

From the Mac (second terminal):

```bash
./bin/udi-watch-progress --host kznas3-1 --user admin \
  --file /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/NAME.img.zst
```

One-shot:

```bash
ssh admin@kznas3-1 'cat /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/*.progress'
ssh admin@kznas3-1 'ls -lh /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/*.img.zst'
```

## What the helper does

1. `ssh` check (`BatchMode`)
2. `rsync -avz --delete` of this checkout → `--remote-dir` on the NAS (excludes `.git`, images)
3. On the NAS runs:  
   `./bin/usb-disk-imager --host local --device … --out-dir local:…`  
   inside **screen** or **nohup**

## QNAP `screen` + `$TERM too long`

Old QTS `screen` rejects long macOS `TERM`. The helper always uses `TERM=vt100`. Manual fix:

```bash
export TERM=vt100
# or: TERM=vt100 screen -S udi-dump
```

| Tool on QTS | Typical | Role |
|-------------|---------|------|
| `screen` | Often yes | Approaches 1 & 3 |
| `tmux` | Often only via Entware `/opt/bin/tmux` | optional |
| `nohup` | Always | Approach 2 |

## Why earlier Mac-only SSH runs failed

| Attempt | Result |
|---------|--------|
| `--user kzielins` | `Permission denied` on `/dev/sdc` |
| `--user admin` from Mac without screen/nohup | `Broken pipe` / timeout mid-dump |
| `screen` on NAS with default TERM | `$TERM too long - sorry.` |
| Host aliases | LAN: `kznas3` / `nas3`; Tailscale: `kznas3-1` |

## Manual fallback (no helper)

```bash
rsync -avz --delete ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager
screen -S udi-dump
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
# Ctrl-A D
```
