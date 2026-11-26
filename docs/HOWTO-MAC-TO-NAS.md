# HOWTO — prosta ścieżka (to, co działało)

Repo: [usb-disk-imager](https://github.com/kzielins/usb-disk-imager)

Cel: **to samo TUI co wcześniej** + opcjonalnie `screen` w tle + `%` status.  
Bez kombinowania z `udi-rsync-run`, chyba że sam chcesz.

---

## 0) Mac — wejście + update (zawsze)

```bash
cd ~/src/usb-disk-imager
git fetch origin
git checkout main
git reset --hard origin/main
```

(`reset --hard` naprawia divergent branches po checkoutach feature-branchy.)

---

## 1) Jak wcześniej — TUI z Maca (menu dysków/katalogów)

To jest oryginalny flow, który Ci chodził:

```bash
cd ~/src/usb-disk-imager
git reset --hard origin/main

./bin/usb-disk-imager --host kznas3-1 --user admin --lang pl
```

- Strzałki / Enter jak zawsze.
- Do odczytu `/dev/sdc` wybierz **`admin`** (nie `kzielins` → Permission denied).
- Długi dump z Maca przez SSH potrafi paść (`Broken pipe`) — wtedy użyj §2.

---

## 2) Screen w tle na NAS (to o co prosiłeś)

Nadal **to samo** `usb-disk-imager`, tylko proces siedzi na NAS w `screen`.

```bash
cd ~/src/usb-disk-imager
git reset --hard origin/main

ssh admin@kznas3-1 'mkdir -p /share/homes/kzielins/ops/usb-disk-imager'
rsync -avz --delete --exclude .git --exclude '.DS_Store' ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/

ssh -t admin@kznas3-1 'export TERM=vt100; cd /share/homes/kzielins/ops/usb-disk-imager; screen -S udi-dump ./bin/usb-disk-imager --host local --lang pl'
```

| | |
|--|--|
| Detach (zostaw w tle) | `Ctrl-A` potem `D` |
| Wróć | `ssh -t admin@kznas3-1 'export TERM=vt100; screen -r udi-dump'` |
| Zabić sesję | `ssh admin@kznas3-1 'export TERM=vt100; screen -S udi-dump -X quit'` |

`TERM=vt100` = fix na QNAP `$TERM too long`.

Na NAS ścieżka toola: `/share/homes/kzielins/ops/usb-disk-imager`  
**Nie** `~/src/...` (to tylko Mac).

---

## 3) Status % (bez attacha do screena)

Po starcie **execute** (gdy leci dump):

```bash
cd ~/src/usb-disk-imager
./bin/udi-status --host kznas3-1 --user admin --dir /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 --watch
```

`percent = bajty przeczytane z dysku / rozmiar dysku` (nie rozmiar `.zst`).

---

## Czego NIE używać, jeśli chcesz „jak było”

- `udi-rsync-run --approach wizard` — extra wrapper; łatwo wpaść w stary screen / goły shell admina.
- `udi-rsync-run ... --execute --yes` — **celowo bez menu**.

Opcjonalny helper `udi-rsync-run` zostaje w repo, ale **nie jest wymagany**.
