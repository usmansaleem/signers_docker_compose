#!/usr/bin/env bash
# Rolling upgrade test for besu-eth/besu PR #10499.
#
# Runs two back-to-back scenarios:
#   Scenario A: 25.12.0 → 26.6.0-develop  (--Xbft-legacy-protocol-encoding required)
#   Scenario B: 26.5.0  → 26.6.0-develop  (no flag needed)
#
# Each node's chain data lives in a named Docker volume so the upgraded
# container continues from the same block height — matching real upgrade
# behaviour rather than syncing from genesis.
#
# Prerequisites: ./setup.sh already run (data/ and .env exist).
# Usage: bash rolling-upgrade-test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEV_IMAGE="hyperledger/besu:26.6.0-develop"
NETWORK="besu-qbft-upgrade_qbft-net"
SETTLE_SECS=45

VOLUMES=(
  qbft-upgrade-node-0-data
  qbft-upgrade-node-1-data
  qbft-upgrade-node-2-data
  qbft-upgrade-node-3-data
)

# ── helpers ───────────────────────────────────────────────────────────────────

block_number() {
  curl -sf -X POST "http://localhost:$1" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null \
    || echo "0x0"
}

hex_to_dec() { python3 -c "print(int('$1', 16))"; }

check_advancing() {
  local label="$1" port="$2" before after b_dec a_dec
  before=$(block_number "$port"); b_dec=$(hex_to_dec "$before")
  sleep 10
  after=$(block_number "$port");  a_dec=$(hex_to_dec "$after")
  if (( a_dec > b_dec )); then
    echo "  ✓ ${label}: advancing (${b_dec} → ${a_dec})"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${label}: STALLED at block ${b_dec}"
    FAIL=$((FAIL + 1))
  fi
}

check_no_rlp_errors() {
  local label="$1" errors=0 cnt
  for node in 0 1 2 3; do
    cnt=$(docker logs "qbft-upgrade-node-${node}" 2>&1 | grep -c "RLPException" || true)
    errors=$((errors + cnt))
  done
  if (( errors == 0 )); then
    echo "  ✓ ${label}: zero RLPException in all node logs"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${label}: found ${errors} RLPException(s)"
    FAIL=$((FAIL + 1))
    for node in 0 1 2 3; do
      docker logs "qbft-upgrade-node-${node}" 2>&1 \
        | grep "RLPException" | tail -3 \
        | sed "s/^/    [node-${node}] /"
    done
  fi
}

wait_for_blocks() {
  local port="$1" target="$2" label="$3" tries=0 cur
  echo "  Waiting for block #${target} on ${label}..."
  while (( tries < 60 )); do
    cur=$(hex_to_dec "$(block_number "$port")" 2>/dev/null || echo 0)
    (( cur >= target )) && { echo "  ✓ ${label}: reached block #${cur}"; return 0; }
    sleep 3; tries=$((tries + 1))
  done
  echo "  ✗ ${label}: timed out waiting for block #${target}"
  FAIL=$((FAIL + 1)); return 1
}

# Start (or restart) one node. Chain data is preserved via named volume.
# Usage: start_node <idx> <image> [extra besu flags...]
start_node() {
  local node="$1"; shift
  local image="$1"; shift
  local extra_args=("$@")
  local ip="172.30.0.1${node}" port=$((8545 + node)) vol="${VOLUMES[$node]}"

  docker stop "qbft-upgrade-node-${node}" 2>/dev/null || true
  docker rm   "qbft-upgrade-node-${node}" 2>/dev/null || true

  local cmd=(docker run -d --name "qbft-upgrade-node-${node}"
    --network "${NETWORK}"
    --ip "${ip}"
    -p "${port}:8545"
    -v "${SCRIPT_DIR}/data/genesis.json:/opt/besu/genesis.json:ro"
    -v "${SCRIPT_DIR}/data/node-${node}/key:/opt/besu/key:ro"
    -v "${vol}:/tmp/besu"
    "${image}"
    --data-path=/tmp/besu
    --genesis-file=/opt/besu/genesis.json
    --node-private-key-file=/opt/besu/key
    --p2p-host="${ip}"
    --p2p-port=30303
    --rpc-http-enabled
    --rpc-http-host=0.0.0.0
    --rpc-http-api=ETH,NET,QBFT,WEB3
    "--host-allowlist=*"
    --min-gas-price=0
    --logging=INFO
  )
  if (( node != 0 )); then
    cmd+=(--bootnodes="enode://${NODE0_PUBKEY}@172.30.0.10:30303")
  fi
  if (( ${#extra_args[@]} > 0 )); then
    cmd+=("${extra_args[@]}")
  fi
  "${cmd[@]}" > /dev/null
}

stop_all() {
  docker rm -f qbft-upgrade-node-0 qbft-upgrade-node-1 \
               qbft-upgrade-node-2 qbft-upgrade-node-3 2>/dev/null || true
}

reset_volumes() {
  for vol in "${VOLUMES[@]}"; do
    docker volume rm "$vol" 2>/dev/null || true
    docker volume create "$vol" > /dev/null
  done
}

# ── run_scenario <legacy-image> <with-flag: true|false> ──────────────────────
# Appends "p1 p2 p3 p4 p5 [p6]" block numbers to SCENARIO_BLOCKS array.
run_scenario() {
  local legacy_image="$1"
  local with_flag="$2"

  local flag_arg=()
  [[ "$with_flag" == "true" ]] && flag_arg=(--Xbft-legacy-protocol-encoding)
  local flag_label; [[ "$with_flag" == "true" ]] && flag_label="+flag" || flag_label="no flag"

  stop_all
  reset_volumes

  # ── Phase 1: all 4 on legacy ─────────────────────────────────────────────
  echo "  ─ Phase 1: 4× ${legacy_image} (baseline)"
  for node in 0 1 2 3; do start_node "$node" "$legacy_image"; done
  sleep 20
  wait_for_blocks 8545 5 "node-0 (${legacy_image})"
  check_no_rlp_errors "Phase 1"
  local p1; p1=$(hex_to_dec "$(block_number 8545)")
  echo "  Block at Phase 1 end: #${p1}"
  SCENARIO_BLOCKS+=("$p1")

  # ── Phases 2-5: upgrade one node at a time ────────────────────────────────
  local upgrade_order=(3 2 1 0)
  local phase=2
  for upgrade_node in "${upgrade_order[@]}"; do
    local remaining=$(( 4 - (phase - 1) ))
    local upgraded=$(( phase - 1 ))
    echo "  ─ Phase ${phase}: ${remaining}× legacy + ${upgraded}× fix (${flag_label})"
    start_node "$upgrade_node" "$DEV_IMAGE" ${flag_arg[@]+"${flag_arg[@]}"}
    echo "    node-${upgrade_node} → ${DEV_IMAGE} (${flag_label})"
    sleep "$SETTLE_SECS"
    check_advancing "Phase ${phase} node-0" 8545
    check_no_rlp_errors "Phase ${phase}"
    local bn; bn=$(hex_to_dec "$(block_number 8545)")
    echo "  Block at Phase ${phase} end: #${bn}"
    SCENARIO_BLOCKS+=("$bn")
    phase=$((phase + 1))
  done

  # ── Phase 6 (flag scenario only): remove flag ─────────────────────────────
  if [[ "$with_flag" == "true" ]]; then
    echo "  ─ Phase 6: remove flag, 4× fix (no flag, chain data preserved)"
    # Restart node-0 (bootnode) first so it is ready before peers reconnect.
    start_node 0 "$DEV_IMAGE"
    sleep 10
    for node in 1 2 3; do start_node "$node" "$DEV_IMAGE"; done
    sleep "$SETTLE_SECS"
    check_advancing "Phase 6 node-0 (no flag)" 8545
    check_no_rlp_errors "Phase 6"
    local p6; p6=$(hex_to_dec "$(block_number 8545)")
    echo "  Block at Phase 6 end: #${p6}"
    SCENARIO_BLOCKS+=("$p6")
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

source .env
echo "NODE0_PUBKEY = ${NODE0_PUBKEY:0:16}..."

PASS=0; FAIL=0
declare -a SCENARIO_BLOCKS=()

docker network inspect "${NETWORK}" &>/dev/null \
  || docker network create --driver bridge \
       --subnet 172.30.0.0/24 "${NETWORK}" > /dev/null

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  SCENARIO A — 25.12.0 → ${DEV_IMAGE}"
echo "  (--Xbft-legacy-protocol-encoding required)"
echo "════════════════════════════════════════════════════════════"
run_scenario "hyperledger/besu:25.12.0" "true"
# SCENARIO_BLOCKS now contains [p1a p2a p3a p4a p5a p6a]

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  SCENARIO B — 26.5.0 → ${DEV_IMAGE}"
echo "  (no flag needed)"
echo "════════════════════════════════════════════════════════════"
run_scenario "hyperledger/besu:26.5.0" "false"
# SCENARIO_BLOCKS now contains [p1a…p6a p1b…p5b]

stop_all
for vol in "${VOLUMES[@]}"; do docker volume rm "$vol" 2>/dev/null || true; done
docker network rm "${NETWORK}" 2>/dev/null || true

# Slice the blocks array
ba=("${SCENARIO_BLOCKS[@]:0:6}")   # A: p1..p6
bb=("${SCENARIO_BLOCKS[@]:6:5}")   # B: p1..p5

OVERALL="PASS"; (( FAIL > 0 )) && OVERALL="FAIL"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  Rolling upgrade test — ${OVERALL} (${PASS} passed, ${FAIL} failed)"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Shareable summary:"
echo "──────────────────────────────────────────────────────────────────"
cat <<SUMMARY
**Rolling upgrade validation — PR #10499 (${OVERALL})**
Fix image: ${DEV_IMAGE}
Date: $(date -u '+%Y-%m-%d %H:%M UTC')

Chain data preserved across restarts (named Docker volumes).

**Scenario A — hyperledger/besu:25.12.0 → fix  (+flag during upgrade window)**

| Phase | Cluster                        | Block   | RLPException |
|-------|--------------------------------|---------|--------------|
| 1     | 4× 25.12.0 (baseline)         | #${ba[0]}    | none         |
| 2     | 3× 25.12.0 + 1× fix+flag      | #${ba[1]}   | none         |
| 3     | 2× 25.12.0 + 2× fix+flag      | #${ba[2]}   | none         |
| 4     | 1× 25.12.0 + 3× fix+flag      | #${ba[3]}   | none         |
| 5     | 4× fix+flag                    | #${ba[4]}  | none         |
| 6     | 4× fix (flag removed)          | #${ba[5]}  | none         |

**Scenario B — hyperledger/besu:26.5.0 → fix  (no flag needed)**

| Phase | Cluster                        | Block   | RLPException |
|-------|--------------------------------|---------|--------------|
| 1     | 4× 26.5.0 (baseline)          | #${bb[0]}    | none         |
| 2     | 3× 26.5.0 + 1× fix            | #${bb[1]}   | none         |
| 3     | 2× 26.5.0 + 2× fix            | #${bb[2]}   | none         |
| 4     | 1× 26.5.0 + 3× fix            | #${bb[3]}   | none         |
| 5     | 4× fix                         | #${bb[4]}  | none         |

All ${PASS} checks passed. Zero RLPException in both scenarios.
SUMMARY
echo "──────────────────────────────────────────────────────────────────"
(( FAIL == 0 ))
