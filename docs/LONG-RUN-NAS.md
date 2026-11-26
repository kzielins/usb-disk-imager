# Long-run details (screen / nohup / TERM)

**Operator entry (cd + git pull first):** [HOWTO-MAC-TO-NAS.md](HOWTO-MAC-TO-NAS.md)

## Always on Mac first

```bash
cd ~/src/usb-disk-imager
git pull origin main
```

## Sync + cd paths

| | |
|--|--|
| rsync destination | `/share/homes/kzielins/ops/usb-disk-imager` |
| cd on NAS | `cd /share/homes/kzielins/ops/usb-disk-imager` |

```bash
cd ~/src/usb-disk-imager
git pull origin main

rsync -avz --delete --exclude .git ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager
```

Prefer `./bin/udi-rsync-run` (see HOWTO) — it does pull-synced tree + start for you after you `cd` + `git pull` on the Mac.

## QNAP session tools

| Tool | Typical | Notes |
|------|---------|-------|
| `screen` | Often yes | `$TERM too long` → `export TERM=vt100` |
| `tmux` | Entware `/opt/bin/tmux` | optional |
| `nohup` | Always | `--approach nohup` |

Detach: `Ctrl-A` `D`. Reattach: `TERM=vt100 screen -r udi-dump`.

## Real percent

```bash
cd ~/src/usb-disk-imager
git pull origin main

./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

`percent = read_bytes / total_bytes` from the block device.
