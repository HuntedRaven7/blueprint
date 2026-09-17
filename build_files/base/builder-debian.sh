#!/bin/bash
set -ouex pipefail

# Toolchain bootstrap (moved from Containerfile.debian into this self-contained
# builder script so the unified root Containerfile can drive every variant).
apt-get update -y
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
    build-essential \
    go-md2man \
    libzstd-dev \
    pkgconf \
    libostree-dev \
    libclang-dev \
    ostree

export CARGO_HOME=/tmp/rust
export RUSTUP_HOME=/tmp/rust
export PATH=/tmp/rust/bin:${PATH}

curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --profile minimal -y

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
