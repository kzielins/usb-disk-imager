# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT | **Version:** 2.2.5

Non-destructive CLI/TUI: compressed, SHA256-verified raw images of USB disks over SSH or on the NAS itself.

## Operator path (Mac → NAS)

**Full copy-paste:** **[docs/HOWTO-MAC-TO-NAS.md](docs/HOWTO-MAC-TO-NAS.md)**

| | Path |
|--|--|
| Sync **to** NAS | `/share/homes/kzielins/ops/usb-disk-imager` |
| **cd** on NAS | `cd /share/homes/kzielins/ops/usb-disk-imager` |
| Image out | `/share/homes/kzielins/images_vmware/<job>/` |

```bash
# From Mac clone — rsync + start on NAS (pick approach)
./bin/udi-rsync-run \
  --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --remote-dir /share/homes/kzielins/ops/usb-disk-imager \
  --approach screen-detach --lang pl --execute --yes
# other approaches: --approach nohup | screen-attach
```

### Real percent (not “watch a log”)

`percent = bytes_read_from_device / device_size * 100` (dd position, not `.zst` size).

```bash
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --watch
```

## Quick Start (generic)

```bash
./tests/run-tests.sh
./install.sh --prefix ~/.local
./bin/usb-disk-imager --host my-nas --user admin --device /dev/sdc --execute
```

## Notes
- Use **`admin`/`root`** to read `/dev/sdX`.
- Default is dry-run; `--execute` writes image + SHA256 + manifest.
- Long jobs: [docs/HOWTO-MAC-TO-NAS.md](docs/HOWTO-MAC-TO-NAS.md), [docs/LONG-RUN-NAS.md](docs/LONG-RUN-NAS.md)
- Slimming: [docs/IMAGE-SLIMMING.md](docs/IMAGE-SLIMMING.md)
