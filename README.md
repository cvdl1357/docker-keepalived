# Unofficial Hardened Multi-Arch Keepalived (`docker-keepalived`)

> **Disclaimer:** This is an **unofficial**, community-maintained Docker image for Keepalived and is not affiliated with or endorsed by the upstream Keepalived project. All credit for Keepalived belongs to **Alexandre Cassen (`acassen`)** and the upstream contributors — visit the [official Keepalived website](https://www.keepalived.org/) or the [upstream GitHub repository](https://github.com/acassen/keepalived) for official documentation and source code.

Lightweight, multi-architecture (`linux/amd64`, `linux/arm64`) **Keepalived** container compiled from official upstream release tags ([`acassen/keepalived`](https://github.com/acassen/keepalived)) with LVS/firewall bloat disabled and packaged on **Docker Hardened Images (`dhi.io/alpine-base:3.24`)**.

## Key Features
* **Hardened Minimal Runtime:** Multi-stage build compiles Keepalived in `dhi.io/alpine-base:3.24-dev` and copies only the stripped `keepalived` binary and required shared libraries (`libnl-3`, `libssl`, `libcrypto`) into `dhi.io/alpine-base:3.24`.
* **VRRP-Focused Build:** Compiled with `--disable-lvs`, `--disable-iptables`, and `--disable-nftables` for pure Virtual Router Redundancy Protocol (VRRP) failover with minimal attack surface.
* **100% Compose-Driven or Custom Config:** Auto-generates a unicast VRRP configuration with HTTP health-check tracking directly from environment variables, or accepts a mounted `/etc/keepalived/keepalived.conf`.
* **Automated Upstream Tracking:** Weekly GitHub Actions builds automatically track the latest stable [`acassen/keepalived`](https://github.com/acassen/keepalived) release tag and publish multi-arch images to Docker Hub (`cvdl1357/keepalived`) and GHCR (`ghcr.io/cvdl1357/docker-keepalived`).

## Quick Start (`compose.yaml`)

### Primary Node (`MASTER`)
```yaml
services:
  keepalived:
    image: cvdl1357/keepalived:latest
    container_name: keepalived
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_BROADCAST
      - NET_RAW
    environment:
      VRRP_STATE: MASTER
      VRRP_INTERFACE: eth0
      VRRP_ROUTER_ID: 51
      VRRP_PRIORITY: 100
      VRRP_UNICAST_SRC_IP: 192.168.1.11
      VRRP_UNICAST_PEER_IP: 192.168.1.12
      VRRP_VIRTUAL_IP: 192.168.1.10/24
      VRRP_AUTH_PASS: changeme
      HEALTHCHECK_URL: http://127.0.0.1:8082/ping
```

### Secondary Node (`BACKUP`)
```yaml
services:
  keepalived:
    image: cvdl1357/keepalived:latest
    container_name: keepalived
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_BROADCAST
      - NET_RAW
    environment:
      VRRP_STATE: BACKUP
      VRRP_INTERFACE: eth0
      VRRP_ROUTER_ID: 51
      VRRP_PRIORITY: 90
      VRRP_UNICAST_SRC_IP: 192.168.1.12
      VRRP_UNICAST_PEER_IP: 192.168.1.11
      VRRP_VIRTUAL_IP: 192.168.1.10/24
      VRRP_AUTH_PASS: changeme
      HEALTHCHECK_URL: http://127.0.0.1:8082/ping
```

## Environment Variables

| Variable | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `VRRP_STATE` | Yes | — | Initial VRRP state (`MASTER` or `BACKUP`). |
| `VRRP_INTERFACE` | Yes | — | Host network interface to bind the VIP (e.g., `eth0`, `ovs_eth0`). |
| `VRRP_PRIORITY` | Yes | — | Election priority (`1`–`255`, higher wins; e.g., `100` vs `90`). |
| `VRRP_UNICAST_SRC_IP` | Yes | — | Local host IP address of this node. |
| `VRRP_UNICAST_PEER_IP` | Yes | — | IP address of the peer VRRP node. |
| `VRRP_VIRTUAL_IP` | Yes | — | Floating Virtual IP with CIDR mask (e.g., `192.168.1.10/24`). |
| `VRRP_AUTH_PASS` | Yes | — | VRRP `PASS` authentication secret (max 8 characters). |
| `VRRP_ROUTER_NAME` | No | `${HOSTNAME}` | Identifier written to `global_defs.router_id`. |
| `VRRP_INSTANCE_NAME` | No | `VI_1` | Name of the `vrrp_instance` block. |
| `VRRP_ROUTER_ID` | No | `51` | Virtual router ID (`1`–`255`), must match on both nodes. |
| `VRRP_ADVERT_INT` | No | `1` | VRRP advertisement interval in seconds. |
| `VRRP_NOPREEMPT` | No | `false` | Set to `true` to prevent a recovered higher-priority node from reclaiming the VIP. |
| `HEALTHCHECK_ENABLED` | No | `true` | Set to `false` to disable HTTP endpoint tracking. |
| `HEALTHCHECK_URL` | No | `[http://127.0.0.1:8082/ping](http://127.0.0.1:8082/ping)` | HTTP endpoint probed by BusyBox `wget`. |
| `HEALTHCHECK_INTERVAL` | No | `2` | Seconds between health-check probes. |
| `HEALTHCHECK_TIMEOUT` | No | `2` | HTTP probe timeout in seconds. |
| `HEALTHCHECK_WEIGHT` | No | `-20` | Priority adjustment when the health check fails. |
| `HEALTHCHECK_FALL` | No | `2` | Consecutive failures required to trigger priority reduction. |
| `HEALTHCHECK_RISE` | No | `2` | Consecutive successes required to restore priority. |

## Custom Configuration File
If you mount a file to `/etc/keepalived/keepalived.conf`, the entrypoint skips environment variable templating and passes your file directly to `keepalived`:

```yaml
    volumes:
      - ./keepalived.conf:/etc/keepalived/keepalived.conf:ro
```

## Credits & Upstream Links
* **Keepalived Project:** [https://www.keepalived.org/](https://www.keepalived.org/)
* **Upstream Source Code:** [https://github.com/acassen/keepalived](https://github.com/acassen/keepalived) — created and maintained by **Alexandre Cassen (`acassen`)**.
