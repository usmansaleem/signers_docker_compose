#!/usr/bin/env bash
# Reproduce / verify the Web3Signer /reload memory leak fixed by PR #1167.
#
# Three modes (set via MODE env var):
#   full    (default) — each cycle wipes the key dir and generates KEYS fresh keys.
#   partial           — each cycle removes REMOVE_PER_CYCLE random keys and adds
#                       ADD_PER_CYCLE new ones. Total key count grows over time,
#                       which better matches real-world rotation patterns. Leak
#                       shows as bimap_bientry_count rising faster than the
#                       expected_total column.
#   sign              — seed KEYS keys once, reload, then run k6 signing load
#                       for SIGN_SECS per cycle against the loaded key set.
#                       Keys stay stable across cycles so k6 never signs with
#                       deleted validators. Isolates signing-path heap behaviour
#                       from reload churn.
#
# Usage:
#   ./scripts/memleak-test.sh IMAGE_TAG [CYCLES=5] [KEYS=5000]
#
# Examples:
#   ./scripts/memleak-test.sh web3signer:master-jdk           # full mode, 5 cycles
#   MODE=partial REMOVE_PER_CYCLE=2500 ADD_PER_CYCLE=5000 \
#       ./scripts/memleak-test.sh web3signer:master-jdk 5 5000
#   MODE=sign SIGN_SECS=60 SIGN_VUS=10 \
#       ./scripts/memleak-test.sh web3signer:develop-jdk 10 5000
set -euo pipefail
shopt -s nullglob

IMAGE_TAG="${1:?IMAGE_TAG required (e.g. consensys/web3signer:26.4.0)}"
CYCLES="${2:-5}"
KEYS="${3:-5000}"
MODE="${MODE:-full}"
REMOVE_PER_CYCLE="${REMOVE_PER_CYCLE:-2500}"
ADD_PER_CYCLE="${ADD_PER_CYCLE:-5000}"
SIGN_SECS="${SIGN_SECS:-60}"
SIGN_VUS="${SIGN_VUS:-10}"
SIGN_SCRIPT="${SIGN_SCRIPT:-/Users/usman/work/signers_docker_compose/web3signer-loadtest/sign-loadtest.js}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
W3S_DIR="$ROOT_DIR/web3signer"
KEYGEN_DIR="$ROOT_DIR/gen-keys"
KEYS_HOST_DIR="$W3S_DIR/config/keys"

TAG_SAFE="$(echo "$IMAGE_TAG" | tr '/:' '__')"
TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="${OUTDIR:-$ROOT_DIR/results/${TAG_SAFE}-${TS}}"
mkdir -p "$OUTDIR"

RUN_LOG="$OUTDIR/run.log"
SUMMARY="$OUTDIR/summary.tsv"
METRICS_URL="http://localhost:9001/metrics"
UPCHECK_URL="http://localhost:9000/upcheck"
RELOAD_URL="http://localhost:9000/reload"
PUBKEYS_URL="http://localhost:9000/api/v1/eth2/publicKeys"

# Tee all stdout/stderr into the run log while still showing it live.
exec > >(tee -a "$RUN_LOG") 2>&1

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }
}

require docker
require curl
require jq

cleanup() {
  log "tearing down web3signer stack"
  (cd "$W3S_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
  docker rm -f bls_keys_gen_config >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "image=$IMAGE_TAG cycles=$CYCLES keys=$KEYS outdir=$OUTDIR"

# 1. Pre-flight
log "pre-flight: ensuring docker network w3s_network exists"
docker network inspect w3s_network >/dev/null 2>&1 || docker network create w3s_network

log "pre-flight: clearing previous harness state"
"$SCRIPT_DIR/clear-all.sh" >/dev/null 2>&1 || true

# 2. Start Web3Signer
log "starting web3signer stack"
(cd "$W3S_DIR" && WEB3SIGNER_IMAGE="$IMAGE_TAG" docker compose up -d)

log "waiting for /upcheck"
for _ in $(seq 1 60); do
  if curl -fsS "$UPCHECK_URL" >/dev/null 2>&1; then
    log "web3signer is up"
    break
  fi
  sleep 2
done
curl -fsS "$UPCHECK_URL" >/dev/null || { echo "web3signer never came up"; exit 1; }

# Helpers
pubkey_count() {
  curl -fsS "$PUBKEYS_URL" 2>/dev/null | jq 'length' 2>/dev/null || echo -1
}

# Wait until publicKeys == expected, stable across 2 consecutive polls.
wait_for_keys() {
  local expected="$1" prev=-2 cur=-1 tries=0
  while (( tries < 180 )); do
    cur="$(pubkey_count)"
    if [[ "$cur" == "$expected" && "$prev" == "$expected" ]]; then
      log "publicKeys count stable at $cur"
      return 0
    fi
    prev="$cur"
    tries=$((tries+1))
    sleep 2
  done
  log "ERROR: timed out waiting for publicKeys == $expected (last=$cur)"
  return 1
}

gen_keys() {
  local count="${1:-$KEYS}"
  log "generating $count keys into $KEYS_HOST_DIR"
  docker rm -f bls_keys_gen_config >/dev/null 2>&1 || true
  (cd "$KEYGEN_DIR" && KEYS_COUNT="$count" docker compose -f ./compose.bls.config.yml up --abort-on-container-exit)
}

wipe_keys() {
  log "wiping $KEYS_HOST_DIR (preserving .gitignore)"
  find "$KEYS_HOST_DIR" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
}

# Remove N random .yaml files (and their matching .json keystores) from the
# keys dir. Used by MODE=partial to simulate partial rotation.
# Fisher-Yates shuffle in awk (single process, no SIGPIPE risk).
remove_random_keys() {
  local n="$1"
  local picked
  picked=$(cd "$KEYS_HOST_DIR" && ls -1 2>/dev/null | grep '\.yaml$' || true)
  [[ -z "$picked" ]] && { log "no yaml keys to remove"; return 0; }
  local selected
  selected=$(printf '%s\n' "$picked" | awk -v n="$n" '
    BEGIN { srand() }
    { a[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        r = int(rand() * (NR - i + 1)) + i
        t = a[i]; a[i] = a[r]; a[r] = t
      }
      for (i = 1; i <= n && i <= NR; i++) print a[i]
    }')
  local removed=0
  while IFS= read -r yf; do
    [[ -z "$yf" ]] && continue
    local base="${yf%.yaml}"
    rm -f "$KEYS_HOST_DIR/$yf" "$KEYS_HOST_DIR/$base.json"
    removed=$((removed + 1))
  done <<< "$selected"
  log "removed $removed random yaml/json pairs"
}

force_gc() {
  docker exec ws-develop jcmd 1 GC.run >/dev/null
}

capture() {
  local cycle="$1"
  local expected_total="$2"
  local metrics_file="$OUTDIR/cycle-$cycle.metrics"
  local hist_file="$OUTDIR/cycle-$cycle.histogram"
  local jstat_file="$OUTDIR/cycle-$cycle.jstat"
  local heapinfo_file="$OUTDIR/cycle-$cycle.heapinfo"

  curl -fsS "$METRICS_URL" \
    | grep -E '^jvm_memory_|^jvm_gc_collection_seconds|^jvm_gc_memory' \
    > "$metrics_file"
  docker exec ws-develop jcmd 1 GC.class_histogram > "$hist_file"
  docker exec ws-develop jstat -gc 1 > "$jstat_file" 2>/dev/null || true
  docker exec ws-develop jcmd 1 GC.heap_info > "$heapinfo_file" 2>/dev/null || true

  # Heap dump on first + last cycle only (costly, ~500MB+ each).
  if [[ "$cycle" -eq 0 || "$cycle" -eq "$CYCLES" ]]; then
    local dump_name="cycle-$cycle.hprof"
    log "cycle=$cycle: taking heap dump /heapdumps/$dump_name"
    docker exec ws-develop jcmd 1 GC.heap_dump "/heapdumps/$dump_name" >/dev/null 2>&1 || true
    # `./heapdumps` is mounted to /heapdumps; copy into results dir so it travels with the run.
    if [[ -f "$W3S_DIR/heapdumps/$dump_name" ]]; then
      mv "$W3S_DIR/heapdumps/$dump_name" "$OUTDIR/"
    fi
  fi

  local heap oldgen bimap sig
  # Heap used — match either the simpleclient `jvm_memory_bytes_used{area="heap"}` or
  # the Micrometer `jvm_memory_used_bytes{area="heap"}` naming.
  heap=$(grep -E '^jvm_memory_(bytes_used|used_bytes)\{[^}]*area="heap"' "$metrics_file" | awk '{print $NF}' | head -1)
  oldgen=$(grep -E '^jvm_memory_(pool_bytes_used|pool_used_bytes|used_bytes)\{[^}]*(pool|id)="G1 Old Gen"' "$metrics_file" | awk '{print $NF}' | head -1)
  bimap=$(grep 'com.google.common.collect.HashBiMap\$BiEntry$' "$hist_file" | awk '{print $2}' || true)
  sig=$(grep 'tech.pegasys.web3signer.signing.BlsArtifactSigner$' "$hist_file" | awk '{print $2}' || true)
  bimap="${bimap:-0}"
  sig="${sig:-0}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$cycle" "$expected_total" "${heap:-NA}" "${oldgen:-NA}" "$bimap" "$sig" >> "$SUMMARY"
  log "cycle=$cycle expected_total=$expected_total heap=${heap:-NA} old_gen=${oldgen:-NA} bimap_bientry=$bimap artifact_signer=$sig"
}

# Summary header
printf 'cycle\texpected_total\theap_used_bytes\told_gen_bytes\tbimap_bientry_count\tartifact_signer_count\n' > "$SUMMARY"

log "mode=$MODE keys=$KEYS remove_per_cycle=$REMOVE_PER_CYCLE add_per_cycle=$ADD_PER_CYCLE"

# 3. Seed initial KEYS
gen_keys "$KEYS"
current_total="$KEYS"

# 4. Cycle 0 (initial load)
log "cycle 0: initial reload"
curl -fsS -X POST "$RELOAD_URL" >/dev/null
wait_for_keys "$current_total"
force_gc
capture 0 "$current_total"

# 5. Cycle loop
for i in $(seq 1 "$CYCLES"); do
  case "$MODE" in
    full)
      log "cycle $i: full replace — wipe all + gen $KEYS"
      wipe_keys
      gen_keys "$KEYS"
      current_total="$KEYS"
      curl -fsS -X POST "$RELOAD_URL" >/dev/null
      wait_for_keys "$current_total"
      ;;
    partial)
      log "cycle $i: partial rotation — remove $REMOVE_PER_CYCLE + add $ADD_PER_CYCLE"
      remove_random_keys "$REMOVE_PER_CYCLE"
      gen_keys "$ADD_PER_CYCLE"
      current_total=$((current_total - REMOVE_PER_CYCLE + ADD_PER_CYCLE))
      curl -fsS -X POST "$RELOAD_URL" >/dev/null
      wait_for_keys "$current_total"
      ;;
    sign)
      # Keys stay stable across cycles — k6 always signs with loaded validators.
      # Run k6 sign-loadtest against the live endpoint for SIGN_SECS.
      log "cycle $i: k6 signing load — duration=${SIGN_SECS}s vus=${SIGN_VUS}"
      command -v k6 >/dev/null 2>&1 || { echo "k6 not installed"; exit 1; }
      [[ -f "$SIGN_SCRIPT" ]] || { echo "sign script not found: $SIGN_SCRIPT"; exit 1; }
      k6 run --quiet --duration "${SIGN_SECS}s" --vus "$SIGN_VUS" \
        --summary-export "$OUTDIR/cycle-$i.k6.json" \
        "$SIGN_SCRIPT" > "$OUTDIR/cycle-$i.k6.log" 2>&1 \
        || { echo "k6 run failed; see $OUTDIR/cycle-$i.k6.log"; exit 1; }
      ;;
    *)
      echo "ERROR: unknown MODE=$MODE (use 'full', 'partial', or 'sign')"; exit 1 ;;
  esac
  force_gc
  capture "$i" "$current_total"
done

log "done. summary:"
cat "$SUMMARY"
log "artifacts in $OUTDIR"
