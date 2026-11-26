# Long-run details (screen / nohup / TERM)

**Start here for Mac → NAS copy-paste:** [HOWTO-MAC-TO-NAS.md](HOWTO-MAC-TO-NAS.md)

## Sync + cd paths

| | |
|--|--|
| rsync destination | `/share/homes/kzielins/ops/usb-disk-imager` |
| cd on NAS | `cd /share/homes/kzielins/ops/usb-disk-imager` |

Prefer `./bin/udi-rsync-run` from the Mac (3 approaches). Manual:

```bash
rsync -avz --delete --exclude .git ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager
```

## QNAP session tools

| Tool | Typical | Notes |
|------|---------|-------|
| `screen` | Often yes | `$TERM too long` → `export TERM=vt100` |
| `tmux` | Entware `/opt/bin/tmux` | optional |
| `nohup` | Always | `--approach nohup` |

Detach screen: `Ctrl-A` `D`. Reattach: `TERM=vt100 screen -r udi-dump`.

## Real percent

```bash
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

`percent = read_bytes / total_bytes` from the block device (see `.progress` + `.udi-job`).
