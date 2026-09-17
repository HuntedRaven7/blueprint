#!/bin/bash
set -ouex pipefail

# Add the SELinux repo, until upstream will make SELinux optional.
# https://github.com/bootc-dev/bootc/issues/2431

echo -e "[selinux]\nServer = https://github.com/archlinuxhardened/selinux/releases/download/ArchLinux-SELinux\nSigLevel = Never" >> /etc/pacman.conf

# Toolchain bootstrap (moved from Containerfile.arch into this self-contained
# builder script so the unified root Containerfile can drive every variant).
pacman -Syu --noconfirm \
    base-devel \
    git \
    rust \
    cargo \
    go-md2man \
    ostree \
    glibc \
    pkgconf \
    libselinux \
    clang \
    python-setuptools

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
