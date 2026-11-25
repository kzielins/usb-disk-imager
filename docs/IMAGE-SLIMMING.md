# Image Slimming & OS / User-Data Separation (Roadmap & Architecture)

Post-processing of compressed raw images (`.img.zst` / `.img.gz`) is intentionally isolated from core acquisition (`bin/usb-disk-imager`) into `lib/slim.sh` so source acquisition remains strictly read-only.

## Two-Stage Workflow (Linux Host with `losetup` + `zstd`)
1. **Acquire Master Image (Read-Only):**
   `usb-disk-imager --host my-nas --user admin --device /dev/sdc --mode raw --execute`
2. **Unpack Sparse & Attach Partitions:**
   `zstd -d --sparse master.img.zst -o work-slim.img`
   `LOOP_DEV=$(sudo losetup --find --show --partscan work-slim.img)`
3. **Extract User Data Only (Read-Only Mount):**
   Mount OS/data partition read-only and archive `Users/` (excluding `Default`, `Public`, `All Users`, and `AppData/Local/Temp`) or `/home` into `user-data-only.tar.zst`.
4. **Slim OS Image (Read-Write Mount + Zero-Fill):**
   Remove `hiberfil.sys`, `pagefile.sys`, `swapfile.sys`, `Windows/SoftwareDistribution/Download/*`, and targeted user profile directories (preserving `Users/Default` and `Users/Public`), then zero-fill free space (`dd if=/dev/zero of=/mnt/img_rw/zero.fill bs=4M; sync; rm -f /mnt/img_rw/zero.fill`) before re-compressing with `zstd -T0 -3 --sparse`.
