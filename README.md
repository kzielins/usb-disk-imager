# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT | **Version:** 2.2.8

Non-destructive CLI/TUI: compressed, SHA256-verified USB disk images over SSH or on the NAS.

## Prosta ścieżka (zalecana)

Pełny opis: **[docs/HOWTO-MAC-TO-NAS.md](docs/HOWTO-MAC-TO-NAS.md)**

**v2.2.7:** interaktywny wybór na Macu → po EXECUTE dump leci **detached na NAS** (`screen udi-sdc`). Mac możesz odłączyć; monitoruj `udi-status`.

```bash
cd ~/src/usb-disk-imager
git fetch origin && git checkout main && git reset --hard origin/main

# Interaktywne menu (plan) — execute odstawia job na NAS
./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl

# Monitor (Mac nie musi trzymać SSH dumpa)
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126 --watch

# Opcjonalnie podejrzyj screen na NAS
ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-sdc'
```

## Notes
- Do `/dev/sdX` użyj **`admin`/`root`**.
- Default = dry-run; zapis po potwierdzeniu / `--execute`.
- Slimming: [docs/IMAGE-SLIMMING.md](docs/IMAGE-SLIMMING.md)
