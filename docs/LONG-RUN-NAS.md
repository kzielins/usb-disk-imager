# Long-running USB image dumps on NAS (screen / tmux / nohup + % progress)

**Repo:** [github.com/kzielins/usb-disk-imager](https://github.com/kzielins/usb-disk-imager) (not the infra meta-repo).

Imaging a ~500 GB disk with zstd + SHA256 can take hours. Do **not** rely on a laptop SSH session alone: sleep, Tailscale flaps, or a quiet SSH channel cause `Broken pipe` / `Operation timed out`. Prefer a **detachable session on the NAS** (`--host local`) as a privileged user (`admin` / `root`). User `kzielins` usually gets `dd: can't open '/dev/sdc': Permission denied`.

## 0) One-time: put the tool on the NAS

From your Mac (with the repo checked out):

```bash
rsync -avz --delete ./ admin@kznas3-1:/share/homes/kzielins/ops/usb-disk-imager/
```

Or on the NAS (if `git` / Entware exists):

```bash
cd /share/homes/kzielins/ops
git clone https://github.com/kzielins/usb-disk-imager.git
```

## 1) What “screen-like” tools exist on QNAP QTS

| Tool | Typical on QTS | Notes |
|------|----------------|-------|
| `screen` | Often yes | Old binary: `$TERM too long - sorry.` → fix TERM (below) |
| `tmux` | Often **no** unless Entware | Try `/opt/bin/tmux` |
| `nohup` + `&` | Always | Best fallback; log + pid file; no attach UI |
| `setsid` | Sometimes | Same idea as nohup |

Check on the NAS:

```bash
command -v screen; command -v tmux; command -v nohup; ls /opt/bin/tmux 2>/dev/null
```

### Fix for `$TERM too long - sorry.`

macOS / modern terminals send a long `TERM` (e.g. `xterm-256color` variants). QNAP `screen` rejects it.

```bash
export TERM=vt100
# or for one shot:
TERM=vt100 screen -S udi-sdc
```

## 2) Recommended: run **on the NAS** inside screen

SSH in (Tailscale MagicDNS name, e.g. `kznas3-1`, or LAN alias from `/etc/hosts`):

```bash
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager
screen -S udi-sdc
```

Inside screen (dry-run first, then execute):

```bash
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
```

| Key | Action |
|-----|--------|
| `Ctrl-A` then `D` | Detach (job keeps running) |
| `TERM=vt100 screen -ls` | List sessions |
| `TERM=vt100 screen -r udi-sdc` | Reattach |
| `TERM=vt100 screen -d -r udi-sdc` | Take over attached session |

Leave the Mac. Imaging continues on the NAS.

## 3) Fallback: `nohup` (no screen attach)

On the NAS as `admin`:

```bash
cd /share/homes/kzielins/ops/usb-disk-imager
OUT=/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125
mkdir -p "$OUT"
nohup ./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir "local:${OUT}" --mode raw --lang pl --yes --execute \
  > "${OUT}/udi-run.log" 2>&1 &
echo $! > "${OUT}/udi-run.pid"
```

Later:

```bash
tail -n 50 "${OUT}/udi-run.log"
ps -p "$(cat "${OUT}/udi-run.pid")" -o pid,etime,cmd
```

## 4) Monitor **percent progress** without attaching

From v2.2.4 the remote/local NAS pipeline writes a sibling file:

`<image>.img.zst.progress`

Example line:

```text
2026-11-26T12:00:00Z | stage=imaging | read=123456789012/512110190592 (24%) | out_bytes=45678901234
```

`read=… (N%)` is bytes read from the block device (true progress). `out_bytes` is compressed size (not %).

### From the Mac (no screen attach)

```bash
./bin/udi-watch-progress --host kznas3-1 --user admin \
  --file /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/SOME.img.zst
```

One-shot:

```bash
ssh admin@kznas3-1 'cat /share/homes/kzielins/images_vmware/.../*.progress'
ssh admin@kznas3-1 'ls -lh /share/homes/kzielins/images_vmware/.../*.img.zst'
```

BusyBox loop if `watch` is missing:

```bash
ssh admin@kznas3-1 'while sleep 10; do date -u; cat /path/to/file.img.zst.progress 2>/dev/null; ls -lh /path/to/file.img.zst 2>/dev/null; echo; done'
```

### If you reattach to screen

You also see the same progress lines on stderr every ~10s (they keep SSH alive when you *do* run over SSH).

## 5) If you insist on driving from the Mac over SSH

1. Use **`admin`** (not `kzielins`) so `/dev/sdc` is readable.
2. Run the **client** inside local `screen`/`tmux` on the Mac so a closed Terminal tab does not kill it.
3. Prefer writing **`remote:/share/...`** so compression stays on the NAS (less Tailscale traffic).
4. Still prefer NAS-local `--host local` for multi-hour jobs.

```bash
# on Mac
screen -S udi-mac
./bin/usb-disk-imager --host kznas3-1 --user admin --device /dev/sdc \
  --out-dir remote:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
# Ctrl-A D to detach
```

Second terminal — progress only:

```bash
./bin/udi-watch-progress --host kznas3-1 --user admin \
  --file /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/<name>.img.zst
```

## 6) Copy-paste checklist for your current dump (`/dev/sdc` @ kznas3-1)

```bash
# Mac → NAS
ssh admin@kznas3-1
export TERM=vt100
cd /share/homes/kzielins/ops/usb-disk-imager   # or wherever you synced the repo
screen -S udi-sdc
./bin/usb-disk-imager --host local --device /dev/sdc \
  --out-dir local:/share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125 \
  --mode raw --lang pl --yes --execute
# Ctrl-A D
```

Monitor from Mac:

```bash
./bin/udi-watch-progress --host kznas3-1 --user admin \
  --file /share/homes/kzielins/images_vmware/kznas3-1-sdc-Windows-EFI-20261125/
# after the job starts, pass the concrete .img.zst path shown in the summary
```

## 7) Why your earlier runs failed (from the logs)

| Attempt | What happened |
|---------|----------------|
| `--user kzielins` | `Permission denied` on `/dev/sdc`; tool still printed SUKCES (fixed in 2.2.4 — pipefail + tiny-output check + non-zero abort) |
| `--user admin` from Mac | Long SSH went quiet → `Broken pipe` / `Operation timed out` |
| `screen` on NAS | `$TERM too long` → use `TERM=vt100` |
| `ssh kznas3` / hosts file | LAN aliases are `kznas3` / `nas3`; Tailscale name is `kznas3-1` (MagicDNS) |
