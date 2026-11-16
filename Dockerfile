# Stage 1: DHI -dev variant (includes apk for compiling)
FROM dhi.io/alpine-base:3.24-dev AS builder

USER root
ARG KEEPALIVED_VERSION=2.4.3

RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
        autoconf \
        automake \
        build-base \
        file \
        git \
        libnl3-dev \
        linux-headers \
        musl-utils \
        openssl-dev

WORKDIR /src
RUN git clone --depth 1 --branch "v${KEEPALIVED_VERSION}" https://github.com/acassen/keepalived.git . && \
    ./build_setup

# Compile strictly VRRP (disables LVS/iptables/nftables to minimize library surface)
RUN ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-lvs \
        --disable-iptables \
        --disable-nftables && \
    make -j"$(nproc)" && \
    make install && \
    strip /usr/sbin/keepalived

# Stage ONLY keepalived and its extra libraries (do NOT overwrite DHI's musl or busybox)
RUN mkdir -p /rootfs/usr/sbin /rootfs/etc/keepalived && \
    cp /usr/sbin/keepalived /rootfs/usr/sbin/keepalived && \
    ldd /usr/sbin/keepalived | awk '/=>/ {print $3}' | grep -v 'ld-musl' | sort -u | \
        xargs -I{} cp -L --parents {} /rootfs

# Stage 2: Minimal DHI runtime (no apk, no package manager)
FROM dhi.io/alpine-base:3.24

USER 0:0
COPY --from=builder /rootfs /
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
