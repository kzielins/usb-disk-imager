# Screen / TERM na QNAP

Zobacz najpierw prostą ścieżkę: [HOWTO-MAC-TO-NAS.md](HOWTO-MAC-TO-NAS.md).

```bash
export TERM=vt100
screen -S udi-dump ./bin/usb-disk-imager --host local --lang pl
# Ctrl-A D
```

`$TERM too long` → zawsze `TERM=vt100`.
