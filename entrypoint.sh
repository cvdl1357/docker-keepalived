#!/bin/sh
set -e

# Ensure root user/group entries exist for Keepalived's script_user lookup in DHI runtime
grep -q '^root:' /etc/passwd 2>/dev/null || echo 'root:x:0:0:root:/root:/bin/sh' >> /etc/passwd
grep -q '^root:' /etc/group 2>/dev/null || echo 'root:x:0:' >> /etc/group

CONF_FILE="/etc/keepalived/keepalived.conf"

# Generate keepalived.conf from environment variables if not mounted directly
if [ ! -f "$CONF_FILE" ]; then
    : "${VRRP_STATE:?VRRP_STATE must be set (MASTER or BACKUP)}"
    : "${VRRP_INTERFACE:?VRRP_INTERFACE must be set (e.g., eth0)}"
    : "${VRRP_PRIORITY:?VRRP_PRIORITY must be set (e.g., 100 for MASTER, 90 for BACKUP)}"
    : "${VRRP_UNICAST_SRC_IP:?VRRP_UNICAST_SRC_IP must be set}"
    : "${VRRP_UNICAST_PEER_IP:?VRRP_UNICAST_PEER_IP must be set}"
    : "${VRRP_VIRTUAL_IP:?VRRP_VIRTUAL_IP must be set (e.g., 192.168.1.10/24 or comma-separated list)}"
    : "${VRRP_AUTH_PASS:?VRRP_AUTH_PASS must be set (max 8 characters)}"

    : "${VRRP_ROUTER_NAME:=${HOSTNAME:-keepalived}}"
    : "${VRRP_INSTANCE_NAME:=VI_1}"
    : "${VRRP_ROUTER_ID:=51}"
    : "${VRRP_ADVERT_INT:=1}"
    : "${VRRP_NOPREEMPT:=false}"

    : "${HEALTHCHECK_ENABLED:=true}"
    : "${HEALTHCHECK_URL:=http://127.0.0.1:8082/ping}"
    : "${HEALTHCHECK_INTERVAL:=2}"
    : "${HEALTHCHECK_TIMEOUT:=2}"
    : "${HEALTHCHECK_WEIGHT:=-20}"
    : "${HEALTHCHECK_FALL:=2}"
    : "${HEALTHCHECK_RISE:=2}"

    NOPREEMPT_LINE=""
    if [ "$VRRP_NOPREEMPT" = "true" ]; then
        NOPREEMPT_LINE="    nopreempt"
    fi

    VIP_LINES=""
    OLD_IFS="$IFS"
    IFS=','
    for vip in $VRRP_VIRTUAL_IP; do
        vip="$(echo "$vip" | tr -d ' ')"
        [ -n "$vip" ] && VIP_LINES="${VIP_LINES}        ${vip}\n"
    done
    IFS="$OLD_IFS"

    HEALTHCHECK_SCRIPT_BLOCK=""
    TRACK_SCRIPT_BLOCK=""
    if [ "$HEALTHCHECK_ENABLED" = "true" ]; then
        WGET_BIN="$(command -v wget)"
        if [ -z "$WGET_BIN" ]; then
            echo "[entrypoint] ERROR: wget binary not found in PATH" >&2
            exit 1
        fi

        HEALTHCHECK_SCRIPT_BLOCK=$(cat <<SCRIPT
vrrp_script chk_service {
    script "${WGET_BIN} -q --spider --timeout=${HEALTHCHECK_TIMEOUT} ${HEALTHCHECK_URL}"
    interval ${HEALTHCHECK_INTERVAL}
    weight ${HEALTHCHECK_WEIGHT}
    fall ${HEALTHCHECK_FALL}
    rise ${HEALTHCHECK_RISE}
}
SCRIPT
)
        TRACK_SCRIPT_BLOCK=$(cat <<TRACK
    track_script {
        chk_service
    }
TRACK
)
    fi

    cat <<EOF > "$CONF_FILE"
global_defs {
    router_id ${VRRP_ROUTER_NAME}
    max_auto_priority
    script_user root
    enable_script_security
}

${HEALTHCHECK_SCRIPT_BLOCK}

vrrp_instance ${VRRP_INSTANCE_NAME} {
    state ${VRRP_STATE}
    interface ${VRRP_INTERFACE}
    virtual_router_id ${VRRP_ROUTER_ID}
    priority ${VRRP_PRIORITY}
    advert_int ${VRRP_ADVERT_INT}
${NOPREEMPT_LINE}

    unicast_src_ip ${VRRP_UNICAST_SRC_IP}
    unicast_peer {
        ${VRRP_UNICAST_PEER_IP}
    }

    authentication {
        auth_type PASS
        auth_pass ${VRRP_AUTH_PASS}
    }

    virtual_ipaddress {
$(printf "%b" "$VIP_LINES")    }

${TRACK_SCRIPT_BLOCK}
}
EOF
fi

# Clean up any stale PID files from an unclean container stop
rm -f /var/run/keepalived.pid /var/run/vrrp.pid

# Run Keepalived in the foreground logging to stdout/stderr
exec /usr/sbin/keepalived --dont-fork --log-console --use-file="$CONF_FILE"
