#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/opensuse"/. /

zypper dup -y
zypper install -y \
    patterns-base-base \
    kernel-default \
    kernel-firmware-all \
    systemd \
    dracut \
    ostree \
    btrfsprogs \
    dosfstools \
    e2fsprogs \
    xfsprogs \
    openssh \
    skopeo \
    podman \
    sudo \
    chrony \
    curl \
    wget \
    iwd \
    bubblewrap \
    cpio \
    libcap-progs \
    libcrypto57

if systemctl list-unit-files | grep -q '^systemd-networkd.service'; then
    systemctl enable systemd-networkd
fi
if systemctl list-unit-files | grep -q '^systemd-resolved.service'; then
    systemctl enable systemd-resolved
fi
systemctl enable chronyd sshd iwd
systemctl mask systemd-firstboot.service

echo "uninitialized" > /etc/machine-id

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' > /usr/lib/tmpfiles.d/resolv-conf.conf

printf '[Match]\nType=ether\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/20-wired.network

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd || true

rm -rf /{boot,home,root,srv,mnt,var,usr/local,opt}

mkdir -p /sysroot /boot /usr/lib/ostree /var /var/tmp

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT ../var/usrlocal /usr/local

cp -rv --update=none /usr/etc/* /etc
rm -r /usr/etc

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | tail -n 1)")
printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf
dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KVER" "/usr/lib/modules/$KVER/initramfs.img"

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

zypper clean -a

rm -rf /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
