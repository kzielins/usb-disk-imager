# HOWTO — interaktywny plan na Macu, dump w tle na NAS

Repo: [usb-disk-imager](https://github.com/kzielins/usb-disk-imager) | v2.2.7+

**Wymaganie:** Mac może się rozłączyć na 12–40 h. Długi dump musi iść **na NAS** (screen/nohup), nie przez otwarte SSH z Maca.

## Flow (to jest właściwy)

1. Na Macu: interaktywne TUI (wybór dysku/katalogu, dry-run, potwierdzenia).
2. Po `--execute` / potwierdzeniu: tool **sam** odstawia job na NAS (`screen -dmS udi-sdc`).
3. Mac możesz zamknąć.
4. Monitorujesz `./bin/udi-status … --watch` albo `screen -r`.

---

## 0) Mac — update

```bash
cd ~/src/usb-disk-imager
git fetch origin && git checkout main && git reset --hard origin/main
```

## 1) Interaktywny start (menu), potem auto-detach na NAS

```bash
cd ~/src/usb-disk-imager
./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl
```

- Wybierz dysk / katalog jak zawsze.
- Na EXECUTE (albo komenda z podsumowania z `--execute`): dump **nie** zostaje na kablu SSH.
- Zobaczysz `DETACHED on NAS session 'udi-sdc'` → Mac wolny.

Albo od razu CLI (też detachuje przy `remote:`):

```bash
./bin/usb-disk-imager --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir remote:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126 \
  --mode raw --lang pl --execute --yes
```

`--out-dir remote:…` = zapis na NAS + **detach**.  
Nie używaj długiego dumpa z `local:` na Macu.

## 2) Monitor (Mac może być gdzie indziej)

```bash
cd ~/src/usb-disk-imager
./bin/udi-status --host kznas3-1 --user admin \
  --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126 \
  --watch
```

## 3) Wróć do screena na NAS

```bash
ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-sdc'
```

(`udi-sdc` = `udi-` + basename urządzenia. Lista: `ssh admin@kznas3-1 'export TERM=vt100; screen -ls'`)

Detach znowu: `Ctrl-A` `D`.

## 4) Log

```bash
ssh admin@kznas3-1 'tail -f /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261126/udi-run.log'
```

## Uwagi

- User **`admin`** do `/dev/sdc` (nie `kzielins`).
- `screen` na Macu ≠ job na NAS. Od v2.2.7 execute z `remote:` samo podnosi screen na NAS.
- Jeśli jesteś **już** na NAS (`--host local` w screenie), job leci na pierwszym planie w tej sesji — też OK.
