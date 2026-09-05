#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/debian"/. /

apt-get update -y

PACKAGES=(
    btrfs-progs
    bubblewrap
    cpio
    cryptsetup
    dbus
    dmsetup
    dosfstools
    e2fsprogs
    efibootmgr
    fdisk
    firmware-linux-free
    linux-image-generic
    netplan.io
    network-manager
    libnss-resolve
    libnss-myhostname
    openssh-server
    skopeo
    systemd
    systemd-boot
    systemd-resolved
    tpm2-tools
    xfsprogs
    ostree
    ostree-boot
    sudo
    curl
    wget
    unzip
    git
    ca-certificates
    dracut
    podman
    libcap2-bin
    chrony
    passwd
    zstd
)

# Prevent the kernel postinst (called by linux-image) from invoking
# dracet via kernel-install or /etc/kernel/postinst.d — neither is
# suppressed by --no-triggers because they are direct postinst calls,
# not dpkg triggers. The explicit dracet --force below handles initramfs
# generation with the correct ostree/bootc configuration.
export KERNEL_INSTALL_INITRD_GENERATOR=""
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "${PACKAGES[@]}"

# systemd-cryptenroll (needed to enroll LUKS TPM2 keyslots) ships in a
# separate package on some Debian releases; install it when present.
if apt-cache show systemd-cryptsetup 2>/dev/null | grep -q '^Package:'; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    systemd-cryptsetup
fi

# Triggers (dracut, ca-certificates, ldconfig) are suppressed so the kernel
# postinst doesn't run dracut with the ostree/bootc modules before the ostree
# environment is fully prepared. The explicit dracut call below handles the
# initramfs build with the correct configuration.
dpkg --configure -a --no-triggers --force-confdef --force-confold
update-ca-certificates 2>/dev/null || true
ldconfig

setcap cap_setuid+ep /usr/bin/newuidmap && chmod -s /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap && chmod -s /usr/bin/newgidmap

cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz"

systemctl enable systemd-networkd systemd-resolved ssh

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

mkdir -p /etc/netplan
printf 'network:\n  version: 2\n  ethernets:\n    all-en:\n      match:\n        name: en*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n    all-eth:\n      match:\n        name: eth*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n' > /etc/netplan/90-default.yaml

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

apt-get clean -y

mkdir -p /usr/lib/sysimage
if [ -d /var/lib/dpkg ]; then cp -a /var/lib/dpkg /usr/lib/sysimage/dpkg; fi

mkdir -p /var/lib
ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg

rm -rf /{boot,home,root,srv,mnt,usr/local,opt}

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sfnT sysroot/ostree /ostree
ln -sfnT var/roothome /root
ln -sfnT var/srv /srv
ln -sfnT var/mnt /mnt
ln -sfnT var/opt /opt
ln -sfnT var/home /home
ln -sfnT ../var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

mkdir -p /var/tmp

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | tail -n 1)")
dracut --force --no-hostonly --reproducible --zstd --verbose --kver "${KVER}" "/usr/lib/modules/${KVER}/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
