# HOWTO — interaktywny plan na Macu, dump w tle na NAS

Repo: [usb-disk-imager](https://github.com/kzielins/usb-disk-imager) | v2.2.9+

**Wymaganie:** Mac może się rozłączyć na 12–40 h. Długi dump musi iść **na NAS** (screen), nie przez otwarte SSH z Maca.

## Flow (jedna ścieżka)

1. Mac: `cd` + `git pull` + interaktywne TUI (strzałki).
2. Po **PODSUMOWANIU**: menu **TAK / NIE** (strzałki) — TAK = zapis w tle na NAS.
3. Tool **weryfikuje**, że `dd`/`gzip`/`zstd` żyje + `udi-run.log` ma `LAUNCH`.
4. Auto-start `udi-status --watch` (Ctrl-C = tylko monitor; job na NAS zostaje).
5. Mac możesz zamknąć.

Docelowy katalog (Twój bieżący job):
`/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126`

---

## 0) Mac — update (zawsze pierwsze)

```bash
cd ~/src/usb-disk-imager
git fetch origin && git checkout main && git reset --hard origin/main
```

## 1) Start (interaktywny)

```bash
cd ~/src/usb-disk-imager
./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl
```

- User **`admin`** (musi czytać `/dev/sdc`).
- Po podsumowaniu: strzałkami **TAK — uruchom dump w tle**.
- Nie używaj długiego dumpa z `local:` na Macu.

## 2) Monitor (jedna komenda)

```bash
cd ~/src/usb-disk-imager
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126 \
  --watch
```

Patrz na linie:
- **Live size** — jeśli rośnie, dump idzie (nawet gdy % = 0).
- **Processes** — powinno być `dd` / `gzip` albo `zstd`.
- **Out file / Image** — może być `.img.gz` (gdy na NAS nie ma `zstd`).

## 3) Diag (gdy coś wygląda źle — wklej cały output)

```bash
cd ~/src/usb-disk-imager
./bin/udi-diag --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126
```

Albo surowy wzrost pliku (bez statusa):

```bash
cd ~/src/usb-disk-imager
ssh admin@kznas3-1 'F=/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126/kznas3-1-sdc-Windows-EFI-20261126-20261126-124124Z.img.gz; ls -lh "$F"; sleep 10; ls -lh "$F"; ps w | grep -E "[d]d |[g]zip|[z]std" | grep -v grep'
```

## 4) Screen / log na NAS

```bash
ssh -t admin@kznas3-1 'export TERM=vt100; screen -ls; screen -r udi-sdc'
ssh admin@kznas3-1 'tail -f /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126/udi-run.log'
```

Detach screena: `Ctrl-A` `D`.

## Uwagi (QTS)

- v2.2.9: launcher **bez** `bash -lc` (profil QTS wieszał screen bez `dd` i bez loga).
- Brak `zstd` na PATH → fallback **gzip** (`.img.gz`). To OK — dump działa.
- Stary `*.img.zst.progress` przy 0% + rosnący `.img.gz` = monitor patrzył w zły plik (naprawione w 2.2.9).
- **Nie zabijaj** działającego joba tylko dlatego, że status pokazuje 0%.
