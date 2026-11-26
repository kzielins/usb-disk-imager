# usb-disk-imager

**Author:** Krzysztof Zielinski ([github.com/kzielins](https://github.com/kzielins)) | **License:** MIT | **Version:** 2.2.9

Non-destructive CLI/TUI: compressed, SHA256-verified USB disk images over SSH or on the NAS.

## Prosta ścieżka (zalecana)

Pełny opis: **[docs/HOWTO-MAC-TO-NAS.md](docs/HOWTO-MAC-TO-NAS.md)**

**v2.2.9:** po podsumowaniu menu TAK/NIE (strzałki) → detach na NAS z weryfikacją `dd`/`gzip` → auto `udi-status`. `udi-diag` = jeden dump diagnostyczny. Live size w statusie (dowód że plik rośnie).

```bash
cd ~/src/usb-disk-imager
git fetch origin && git checkout main && git reset --hard origin/main

./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl

./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126 --watch

./bin/udi-diag --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126
```

## Notes
- Do `/dev/sdX` użyj **`admin`/`root`**.
- Default = dry-run; zapis po TAK w menu / `--execute`.
- Brak `zstd` na QTS → `.img.gz` (OK).
- Slimming: [docs/IMAGE-SLIMMING.md](docs/IMAGE-SLIMMING.md)
