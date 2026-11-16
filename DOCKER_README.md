# Hardened Multi-Arch Keepalived (VRRP-Only)

Lightweight, multi-architecture (`linux/amd64`, `linux/arm64`) **Keepalived** container compiled from official upstream release tags (`acassen/keepalived`) with LVS/firewall bloat disabled and packaged on **Docker Hardened Images (`dhi.io/alpine-base:3.24`)**.

* **Source & Documentation:** [github.com/cvdl1357/keepalived](https://github.com/cvdl1357/keepalived)
* **Architectures:** `linux/amd64`, `linux/arm64`
* **Base Runtime:** `dhi.io/alpine-base:3.24`

## Example `compose.yaml`

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

## Required Capabilities & Networking
* `network_mode: host` is required so Keepalived can assign the floating Virtual IP directly to the host network interface.
* `NET_ADMIN`, `NET_BROADCAST`, and `NET_RAW` capabilities are required for VRRP raw sockets, gratuitous ARP announcements, and interface IP management.
