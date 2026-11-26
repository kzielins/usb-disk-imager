# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT | **Version:** 2.2.6

Non-destructive CLI/TUI: compressed, SHA256-verified USB disk images over SSH or on the NAS.

## Prosta ścieżka (zalecana)

Pełny opis: **[docs/HOWTO-MAC-TO-NAS.md](docs/HOWTO-MAC-TO-NAS.md)**

```bash
cd ~/src/usb-disk-imager
git fetch origin && git checkout main && git reset --hard origin/main

# 1) TUI jak wcześniej (z Maca)
./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl

# 2) ALBO to samo TUI w screen na NAS (długi dump w tle):
ssh admin@kznas3-1 'mkdir -p /share/homes/kzielins/ops/usb-disk-imager'
rsync -avz --delete --exclude .git ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
ssh -t admin@kznas3-1 'export TERM=vt100; cd /share/homes/kzielins/ops/usb-disk-imager; screen -S udi-dump ./bin/usb-disk-imager --host local --lang pl'
# Ctrl-A D = detach

# 3) % status z Maca
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 --watch
```

## Notes
- Do `/dev/sdX` użyj **`admin`/`root`**.
- Default = dry-run; zapis po potwierdzeniu / `--execute`.
- Slimming: [docs/IMAGE-SLIMMING.md](docs/IMAGE-SLIMMING.md)
