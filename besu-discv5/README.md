# Besu DiscV5 test harnesses

Two dual-stack (IPv4 + IPv6) compose stacks for exercising Besu's discovery-v5 features locally.

> **Image dependencies.**
> - `compose.yml` uses `hyperledger/besu:develop` — DiscV5 + `--net-restrict` peer permissioning has been merged upstream (PR #9950), so the public develop tag is sufficient.
> - `compose-ipv6-discovery.yml` uses `hyperledger/besu:discv5develop` — this scenario exercises PR #10416 (IPv6 auto-discovery) which is not yet merged. Build that image locally from the PR branch, or retag once it lands.

> **Node keys.** `node1.key`, `node2.key`, `node3.key` are committed deliberately so the ENRs in the compose files stay deterministic across runs. They are throwaway test keys — do not reuse them anywhere real.

## `compose.yml` — peer permissioning via `--net-restrict`

Three nodes on `172.28.0.0/24` + `fd00:dead:beef::/64`:

| Node | IPv4 | Restriction |
|---|---|---|
| node1 | 172.28.0.10 | unrestricted, bootnode |
| node2 | 172.28.0.20 | `--net-restrict=172.28.0.0/28` (allows .1–.14 only) |
| node3 | 172.28.0.30 | unrestricted |

Expected:
- node1 connects to both node2 and node3
- node2 connects to node1, rejects node3 (out of subnet)
- node3 connects to node1; node2 rejects its inbound attempts

```sh
docker compose up
```

RPC ports: node1 `8545`, node2 `8547`, node3 `8549`.

## `compose-ipv6-discovery.yml` — IPv6 auto-discovery (PR #10416)

Tests the path where node2 binds dual-stack (`--p2p-interface-ipv6=::`) but does **not** pass `--p2p-host-ipv6`, so its ENR has to be filled in from peer PONG reports (`MIN_CONFIRMATIONS=2`).

| Node | Role |
|---|---|
| node1 | dual-stack bootnode (advertises ip6/udp6/tcp6 in its ENR) |
| node2 | target — dual-stack bind, no explicit IPv6 host, `--p2p-ipv6-outbound-enabled=true` |
| node3 | witness — dual-stack like node1, provides the 2nd PONG confirmation |

```sh
docker compose -f compose-ipv6-discovery.yml up
```

Check whether auto-discovery fired:

```sh
# admin_nodeInfo should show ip6/udp6/tcp6 fields populated and enr seq > 1
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
  http://localhost:8547
```

## Notes

- `custom-log4j.xml` raises discovery-related package log levels for debugging.
- Docker bridge IPv6 UDP is unreliable for simultaneous handshake on some hosts — not a Besu bug, but expect occasional handshake delays.
- Health gating uses Besu's built-in Dockerfile `HEALTHCHECK` (`[ -f /tmp/pid ]`); node2/node3 wait on node1 via `depends_on: condition: service_healthy`.
