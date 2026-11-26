#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Runs ON the machine that can read the block device (usually the NAS).
# Env (required): DEV RPATH RSHA RPROG RBASE COMP TOTAL RDIR [DEVICE_LABEL]
# Progress is REAL: percent = bytes_read_from_device / TOTAL * 100
# (NOT compressed file size — zstd size is not linear with source).
set -eu
set -o pipefail 2>/dev/null || true

: "${DEV:?}" "${RPATH:?}" "${RSHA:?}" "${RPROG:?}" "${RBASE:?}" "${COMP:?}" "${TOTAL:?}" "${RDIR:?}"
DEVICE_LABEL="${DEVICE_LABEL:-${DEV}}"
STARTED_UTC="${STARTED_UTC:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
JOB_FILE="${JOB_FILE:-$(dirname "${RPATH}")/.udi-job}"

mkdir -p "${RDIR}"
if ! [ -r "${DEV}" ]; then
  echo "ERROR: cannot read ${DEV} (Permission denied?). Use admin/root." >&2
  exit 1
fi

human_bytes() {
  # awk portable GiB with 1 decimal
  awk -v b="$1" 'BEGIN { printf "%.1f" , b/1024/1024/1024 }'
}

out_bytes() {
  if [ -f "${RPATH}" ]; then wc -c < "${RPATH}" 2>/dev/null | tr -d ' '; else echo 0; fi
}

# Write machine-parseable progress + one human line. percent = read/total.
write_prog() {
  local pos="$1" pct="$2" stage="$3" eta="${4:-}" rate="${5:-}"
  local ob now human
  ob="$(out_bytes)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  human=$(printf "%s%% | %s/%s GiB read | out %s GiB | stage=%s" \
    "${pct}" "$(human_bytes "${pos}")" "$(human_bytes "${TOTAL}")" "$(human_bytes "${ob}")" "${stage}")
  if [ -n "${eta}" ] && [ "${eta}" -ge 0 ] 2>/dev/null; then
    human="${human} | ETA ${eta}s"
  fi
  cat > "${RPROG}" << PROG
# usb-disk-imager progress v1 — percent = read_bytes/total_bytes (block device)
updated_utc=${now}
stage=${stage}
device=${DEVICE_LABEL}
image=${RPATH}
read_bytes=${pos}
total_bytes=${TOTAL}
percent=${pct}
out_bytes=${ob}
rate_bytes_per_sec=${rate}
eta_seconds=${eta}
started_utc=${STARTED_UTC}
human=${human}
PROG
  printf "%s\n" "${human}" >&2
}

write_job() {
  cat > "${JOB_FILE}" << JOB
# usb-disk-imager active job — used by bin/udi-status --dir
device=${DEVICE_LABEL}
image=${RPATH}
progress=${RPROG}
sha256=${RSHA}
total_bytes=${TOTAL}
started_utc=${STARTED_UTC}
status=running
JOB
}

monitor_dd() {
  local pid="$1"
  local pos=0 pct=0 prev_pos=0 prev_ts rate eta
  prev_ts=$(date +%s)
  while kill -0 "${pid}" 2>/dev/null; do
    if [ -r "/proc/${pid}/fdinfo/0" ]; then
      pos=$(awk '/^pos:/ {print $2; exit}' "/proc/${pid}/fdinfo/0" 2>/dev/null || echo "${pos}")
    fi
    pct=0
    if [ "${TOTAL}" -gt 0 ] 2>/dev/null; then
      pct=$((pos * 100 / TOTAL))
      [ "${pct}" -gt 100 ] && pct=100
    fi
    now_ts=$(date +%s)
    dt=$((now_ts - prev_ts))
    rate=0
    eta=""
    if [ "${dt}" -gt 0 ]; then
      rate=$(( (pos - prev_pos) / dt ))
      if [ "${rate}" -gt 0 ] && [ "${TOTAL}" -gt "${pos}" ]; then
        eta=$(( (TOTAL - pos) / rate ))
      fi
    fi
    prev_pos="${pos}"
    prev_ts="${now_ts}"
    write_prog "${pos}" "${pct}" "imaging" "${eta}" "${rate}"
    sleep 5
  done
}

raw_fifo=$(mktemp -u /tmp/udi-raw.XXXXXX)
sha_fifo=$(mktemp -u /tmp/udi-sha.XXXXXX)
mkfifo "${raw_fifo}" "${sha_fifo}"
cleanup() { rm -f "${raw_fifo}" "${sha_fifo}"; }
trap cleanup EXIT

write_job
write_prog "0" "0" "start" "" "0"

rc=0
if command -v zstd >/dev/null 2>&1 && [ "${COMP}" = "zstd" ]; then
  (sha256sum < "${sha_fifo}" | awk -v f="${RBASE}" '{print $1 "  " f}' > "${RSHA}") &
  sha_pid=$!
  dd if="${DEV}" bs=4M of="${raw_fifo}" 2>/dev/null &
  dd_pid=$!
  monitor_dd "${dd_pid}" &
  mon_pid=$!
  tee "${sha_fifo}" < "${raw_fifo}" | zstd -T0 -3 -f -o "${RPATH}"
  rc=$?
  wait "${dd_pid}" || rc=$?
  kill "${mon_pid}" 2>/dev/null || true
  wait "${mon_pid}" 2>/dev/null || true
  wait "${sha_pid}" || rc=$?
else
  RPATH="${RPATH%.zst}.gz"
  RSHA="${RPATH}.sha256"
  RPROG="${RPATH}.progress"
  RBASE="$(basename "${RPATH}")"
  write_job
  (sha256sum < "${sha_fifo}" | awk -v f="${RBASE}" '{print $1 "  " f}' > "${RSHA}") &
  sha_pid=$!
  dd if="${DEV}" bs=4M of="${raw_fifo}" 2>/dev/null &
  dd_pid=$!
  monitor_dd "${dd_pid}" &
  mon_pid=$!
  tee "${sha_fifo}" < "${raw_fifo}" | gzip -6 > "${RPATH}"
  rc=$?
  wait "${dd_pid}" || rc=$?
  kill "${mon_pid}" 2>/dev/null || true
  wait "${mon_pid}" 2>/dev/null || true
  wait "${sha_pid}" || rc=$?
fi

final_pos="${TOTAL}"
[ "${TOTAL}" -gt 0 ] || final_pos="$(out_bytes)"
write_prog "${final_pos}" "100" "done" "0" "0"
if [ "${rc}" -eq 0 ]; then
  sed -i.bak 's/^status=running$/status=done/' "${JOB_FILE}" 2>/dev/null || \
    printf "%s\n" "$(grep -v '^status=' "${JOB_FILE}" 2>/dev/null; echo status=done)" > "${JOB_FILE}"
  rm -f "${JOB_FILE}.bak" 2>/dev/null || true
else
  sed -i.bak 's/^status=running$/status=failed/' "${JOB_FILE}" 2>/dev/null || true
  rm -f "${JOB_FILE}.bak" 2>/dev/null || true
fi
[ "${rc}" -eq 0 ] || exit "${rc}"
ob="$(out_bytes)"
if [ "${ob}" -lt 1024 ]; then
  echo "ERROR: output image is tiny (${ob} bytes) — imaging likely failed." >&2
  exit 1
fi
exit 0
