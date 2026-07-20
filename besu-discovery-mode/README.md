# Besu `--discovery-mode` end-to-end test harnesses

Six compose stacks (five 2-node, one 3-node) covering discovery topologies for the shared
DiscV4/DiscV5 transport work (`shared_discv4_discv5` branch). Each has been run end-to-end
against the `hyperledger/besu:sharedtransport-develop` image and confirmed to bond peers
successfully.

> **Image.** All files use `hyperledger/besu:sharedtransport-develop`, built locally from
> the `shared_discv4_discv5` branch via:
> ```sh
> ./gradlew -Prelease.releaseVersion=sharedtransport-develop distDocker
> ```
> Rebuild this image after pulling new changes on that branch before re-running these stacks.

> **Node keys.** `node1.key`, `node2.key`, `node3.key` are the same throwaway test keys used in
> `../besu-discv5/`, copied here so the ENRs/enodes below stay deterministic. Do not reuse them
> anywhere real.

## Scenarios

| File | `--discovery-mode` | Stack | bootnode form |
|---|---|---|---|
| `compose.both-mode.yml` | `BOTH` (default) | dual-stack | enode **and** ENR (comma-separated) |
| `compose.v5-mode.yml` | `V5` | dual-stack | ENR only |
| `compose.v4-mode.yml` | `V4` | dual-stack | enode only |
| `compose.ipv6-only.yml` | `V5` | single-stack IPv6 only, `--p2p-interface=::` | ENR only (ip6/udp6/tcp6 fields, no ip4) |
| `compose.cross-network.yml` | `V4` (all 3 nodes) | 3 nodes on 3 networks: IPv6-only, IPv4-only, and a dual-stack hub attached to both | enode only, per address family (see below) |
| `compose.same-port.yml` | `BOTH` | dual-stack, `--p2p-port-ipv6` explicitly set equal to `--p2p-port` (30303) | enode **and** ENR |

DiscV4 (and therefore `BOTH`) also works on single-stack IPv6-only — there's no dedicated
`compose.v4-mode.yml`-style IPv6-only file for it beyond what `compose.cross-network.yml`'s
node-a already covers; see "DiscV4 on IPv6-only" below for how that was verified.

Each of the five 2-node files is self-contained: node1 is the bootnode (no bootnodes of its
own, hardcoded deterministic enode/ENR values in comments), node2 joins via that value. Node1's
own enode/ENR strings were captured by actually running the image with the exact key/IP/port
config in each file — see "Regenerating bootnode strings" below if you change node1's config.

```sh
docker compose -f compose.both-mode.yml up
# ... in another shell ...
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
  http://localhost:8560 | jq
docker compose -f compose.both-mode.yml down -v
```

RPC ports: `both-mode` 8560/8561, `v5-mode` 8570/8571, `v4-mode` 8580/8581, `ipv6-only`
8590/8591 (node1/node2 respectively), `cross-network` 8600/8601/8602 (node-c/node-a/node-b),
`same-port` 8610/8611 (node1/node2 respectively).

## DiscV4 on IPv6-only single-stack

Unlike an earlier assumption in this PR, DiscV4 does **not** require an IPv4 socket to start —
verified by building upstream/main (before this PR) and confirming its owned-channel
`NettyTransport` already binds `--p2p-interface=::` fine. The shared-transport work's
`SharedDiscoveryTransport` constructor had added a stricter guard rejecting any DiscV4-enabled
config with no IPv4 bind; that guard has been removed to match upstream, and a related bug in
`NettyTransport.start()` (shared mode) — which hardcoded checking only the IPv4 channel — was
fixed to fall back to IPv6. `compose.cross-network.yml`'s node-a (`--discovery-mode=V4`,
single-stack IPv6-only) exercises this directly.

DiscV4 still can't reach an IPv4 recipient from an IPv6-only socket — that's a real network
constraint, not a Besu limitation — but it now surfaces as a quietly-traced
`UnsupportedAddressTypeException` per send, not a reason to refuse to start.

## Verifying UDP gossip and demux routing via logs

`custom-log4j.xml` targets specific classes with TRACE instead of whole packages, so you get
wire-level signal without the discovery package's general TRACE noise (RLP-decode traces,
per-tick bonding-round-skipped spam, etc.):

- **DiscV4 gossip**: `DiscoveryProtocolLogger` logs every PING/PONG/FIND_NEIGHBORS/NEIGHBORS/
  ENR_REQUEST sent and received, with full decoded packet contents.
- **DiscV5 gossip**: the discv5 library's `WhoAreYouPacketHandler` (handshake challenge),
  `HandshakeMessagePacketHandler` (handshake completion), and `MessagePacketHandler`
  (post-handshake FINDNODE/NODES/PING/PONG) log at TRACE. These run on the `disc-v5-dispatch`
  thread — confirming the dedicated V5 dispatch executor (not the shared Netty event-loop
  thread) is what's processing them.
- **Demux routing**: `SharedDiscoveryDemuxHandler` only logs its *drop* paths (too-small,
  oversized-V4, unrecognized packet) — there's no log line for successful routing. The proof
  that demux is classifying correctly is indirect but solid: a packet cannot reach either
  protocol's handler above without first passing through this class, so seeing both V4 and V5
  gossip on the same node with zero drop-path lines (`compose.both-mode.yml`) confirms it's
  routing both protocols correctly off the one shared socket.

```sh
docker compose -f compose.both-mode.yml up -d
sleep 20
docker logs discmode-both-node1 2>&1 | grep DiscoveryProtocolLogger        # V4 gossip
docker logs discmode-both-node1 2>&1 | grep -E 'WhoAreYouPacketHandler|HandshakeMessagePacketHandler|MessagePacketHandler'  # V5 gossip
docker logs discmode-both-node1 2>&1 | grep SharedDiscoveryDemuxHandler    # should be empty in a clean run
docker compose -f compose.both-mode.yml down -v
```

## `compose.cross-network.yml` — cross-network topology

Three nodes, three docker networks, each node representing a different real-world "public
interface" configuration:

| Node | Network(s) | Config | Role |
|---|---|---|---|
| node-a | `net-ipv6-only` only | single-stack IPv6-only | leaf, bootstraps via node-c |
| node-b | `net-ipv4-only` only | single-stack IPv4-only (the common case) | leaf, bootstraps via node-c |
| node-c | both networks | dual-stack hub | bootnode-less; the only node reachable by both leaves |

node-a and node-b have no common address family and **cannot** reach each other directly — this
is the physical reality being modeled, not a bug. Expected result: node-c's `admin_peers` shows
2 peers (one IPv6, one IPv4); node-a and node-b each show exactly 1 peer (node-c); neither shows
the other. No WARN/ERROR spam on any node — confirmed by running this exact stack (see git
history / PR discussion for the verification transcript).

```sh
docker compose -f compose.cross-network.yml up
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
  http://localhost:8600 | jq   # node-c (hub) - expect 2 peers
docker compose -f compose.cross-network.yml down -v
```

## `compose.same-port.yml` — same port for both address families

Sets `--p2p-port-ipv6` explicitly equal to `--p2p-port` (30303) on a dual-stack node, so an
operator only has to open one port in their firewall for both address families. On Linux,
binding two *independent* per-family sockets (one IPv4-only, one IPv6) on the same port number
reliably fails with `BindException: Address already in use`, regardless of bind order — an
IPv6 wildcard (`::`) bind is dual-stack by default and implicitly also claims the IPv4 port
namespace. This is genuine JDK/OS socket behavior, not a Besu bug, and isn't controllable via
Java's public NIO API.

The fix (`NetworkUtility.isMergeableDualStackBind`, consumed by both `SharedDiscoveryTransport`
for UDP discovery and `NettyConnectionInitializer` for RLPx TCP) detects this exact
configuration — both bind hosts are the wildcard address for their family AND the ports match —
and binds a single dual-stack IPv6 socket instead of two, using it for both families. Verified
(on both Linux and macOS, via raw `java.nio.channels` reproduction outside Besu/Netty entirely)
to correctly send/receive both IPv4 and IPv6 traffic with proper `Inet4Address`/`Inet6Address`
sender typing.

Expected: node1 and node2 both log `P2P RLPx agent started and listening on ... (single
dual-stack socket serving both IPv4 and IPv6)` and `Starting discovery on shared UDP socket
(V4 + V5)` — no `BindException` on either node. `admin_peers` on both nodes shows 1 connected
peer, and `NodeRecordManager`'s logged `NodeRecord` shows `tcp`, `udp`, `tcp6`, and `udp6` all
equal to 30303.

```sh
docker compose -f compose.same-port.yml up -d
sleep 20
docker logs discmode-sameport-node1 2>&1 | grep -i BindException   # should be empty
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
  http://localhost:8610 | jq
docker compose -f compose.same-port.yml down -v
```

## Regenerating bootnode strings

If you change a node's key, IP, port, or advertised-host config in any file, the hardcoded
enode/ENR bootnode value(s) depending on it must be recomputed. Run that node alone with the new
config and a fresh (empty) data volume, then grab the logged values:

```sh
docker volume create tmp-node-data
docker run --rm -d --name tmp-node \
  --network <network> --ip <ipv4> --ip6 <ipv6> \
  -v tmp-node-data:/var/lib/besu \
  -v ./node1.key:/opt/besu/node.key:ro \
  hyperledger/besu:sharedtransport-develop \
  --network=dev --rpc-http-enabled --rpc-http-host=0.0.0.0 --data-path=/var/lib/besu \
  --node-private-key-file=/opt/besu/node.key \
  <the same --discovery-mode / --p2p-host* / --p2p-interface* / --p2p-port flags as the file> \
  --discovery-enabled=true --bootnodes
sleep 8
docker logs tmp-node 2>&1 | grep -i "enode url\|enr url"
docker rm -f tmp-node && docker volume rm tmp-node-data
```

Use a **fresh** volume each time — reusing one with a persisted ENR bumps `seq` instead of
producing the clean `seq=1` record the comments in these files describe.

**Dual-stack secondary port gotcha**: a node with a dual-stack *secondary* IPv6 interface
(`--p2p-interface-ipv6`/`--p2p-host-ipv6` set alongside a primary IPv4 interface, as in
`compose.cross-network.yml`'s node-c) binds its IPv6 discovery/RLPx socket on
`--p2p-port + 101` by default (e.g. `30303` → `30404`), not the same port as the primary. Check
`admin_nodeInfo`'s `discoveryV6`/`listenerV6` fields (or set `--p2p-port-ipv6` explicitly) rather
than assuming the IPv6 bootnode string uses the same port as the IPv4 one. This does **not**
apply to a node where IPv6 is the *primary* (single-stack) interface — that binds `--p2p-port`
directly, same as an IPv4-primary node would.

## Notes

- Each scenario uses its own docker network name (scoped by this directory as the compose
  project), so run one at a time — `docker compose -f <file> down -v` before starting the next.
- Health gating uses Besu's built-in Dockerfile `HEALTHCHECK` (`[ -f /tmp/pid ]`); node2 waits
  on node1 via `depends_on: condition: service_healthy`.
- `compose.ipv6-only.yml` and `compose.cross-network.yml`'s node-a/node-b each use a genuinely
  single-family docker network (no IPv4 subnet for the IPv6-only one, no IPv6 for the IPv4-only
  one) so the topology is unambiguous — Besu itself only cares about the
  `--p2p-interface`/`--p2p-host` flags, not what Docker happens to assign, but a pure single-family
  network avoids any ambiguity about whether the test is exercising the single-stack code path.
- `compose.cross-network.yml` uses explicit `enode://` bootnodes throughout (no ENR), so every
  bootstrap target's address family is unambiguous — this avoids relying on the discv5 library
  or DiscV4 to pick the "right" field out of a multi-address record when a peer might not even
  have the socket to use it.
