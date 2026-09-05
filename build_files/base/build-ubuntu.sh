#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/ubuntu"/. /

mkdir -p /var/lib/apt/lists/partial

# Enable universe/multiverse: several packages below (flatpak, just, fzf,
# buildah, grim, ...) live in universe. No-op if the base already lists them.
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    sed -i 's/^Components: .*/Components: main restricted universe multiverse/' \
        /etc/apt/sources.list.d/ubuntu.sources
fi
if [ -f /etc/apt/sources.list ]; then
    sed -i 's/ main$/ main restricted universe multiverse/' /etc/apt/sources.list
fi

apt-get update -y

PACKAGES=(
    btrfs-progs
    bubblewrap
    buildah
    ca-certificates
    amd64-microcode
    systemd-cryptsetup
    cryptsetup
    chrony
    cpio
    cryptsetup
    curl
    dbus
    distrobox
    dmsetup
    dosfstools
    e2fsprogs
    efibootmgr
    fdisk
    ffmpeg
    flatpak
    fuse-overlayfs
    fwupd
    fzf
    git
    go-md2man
    golang-go
    grim
    gstreamer1.0-libav
    gstreamer1.0-plugins-bad
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-ugly
    intel-microcode
    iwd
    jq
    just
    libavcodec-extra
    libcap2-bin
    libtss2-esys-3.0.2-0t64
    libtss2-rc0t64
    libtss2-tcti-device0t64
    libtss2-tctildr0t64
    linux-firmware
    linux-image-generic
    netplan.io
    network-manager
    openssh-server
    ostree
    ostree-boot
    passwd
    plymouth
    plymouth-themes
    podman
    power-profiles-daemon
    powertop
    skopeo
    sudo
    systemd
    systemd-boot
    systemd-boot-efi
    systemd-oomd
    systemd-resolved
    tpm2-tools
    snapd
    apparmor
    apparmor-utils
    unzip
    wayland-utils
    wget
    wl-clipboard
    x11-xserver-utils
    xdg-desktop-portal
    xfsprogs
    zstd
)

# Stub out the initramfs/grub generators before package install: several
# package postinsts (dracut, cryptsetup-initramfs, plymouth, kdump-tools,
# linux-image, ...) call dracut/update-initramfs directly, which would run
# dracut with the stock config before the ostree/bootc environment is ready.
# The explicit dracut --force below builds the initramfs with the correct
# configuration.
printf '#!/bin/sh\nexit 0\n' | tee \
    /usr/sbin/update-initramfs /usr/sbin/mkinitramfs \
    /usr/sbin/update-grub /usr/sbin/grub-mkconfig > /dev/null
chmod +x /usr/sbin/update-initramfs /usr/sbin/mkinitramfs \
    /usr/sbin/update-grub /usr/sbin/grub-mkconfig
mkdir -p /etc/kernel/postinst.d /usr/share/kernel/postinst.d
printf '#!/bin/sh\nexit 0\n' > /etc/kernel/postinst.d/kdump-tools
printf '#!/bin/sh\nexit 0\n' > /etc/kernel/postinst.d/dracut
printf '#!/bin/sh\nexit 0\n' > /usr/share/kernel/postinst.d/zz-systemd-boot
chmod +x /etc/kernel/postinst.d/kdump-tools \
    /etc/kernel/postinst.d/dracut \
    /usr/share/kernel/postinst.d/zz-systemd-boot

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "${PACKAGES[@]}"

dpkg --configure -a --no-triggers --force-confdef --force-confold
update-ca-certificates 2>/dev/null || true
ldconfig

# Install dracut and cryptsetup-initramfs separately after the main package set.
# Their postinst scripts call dracut directly, bypassing the stubs above.
# Installing them separately ensures dpkg configures dracut (via stub) before
# cryptsetup-initramfs tries to resolve its linux-initramfs-tool dependency.
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    dracut
dpkg --configure -a --no-triggers --force-confdef --force-confold
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    cryptsetup-initramfs

# systemd-cryptenroll (needed to enroll LUKS TPM2 keyslots) ships in a
# separate package on some releases; install it when present.
if apt-cache show systemd-cryptenroll 2>/dev/null | grep -q '^Package:'; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        -o Dpkg::Options::="--no-triggers" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        systemd-cryptenroll
fi

setcap cap_setuid+ep /usr/bin/newuidmap && chmod -s /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap && chmod -s /usr/bin/newgidmap

cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz"

systemctl enable NetworkManager systemd-resolved ssh apparmor snapd
systemctl mask systemd-firstboot.service

# L+! rather than L!: Ubuntu's base ships a 0-byte /etc/resolv.conf, which a
# plain L! tmpfiles rule leaves untouched (it only links empty paths), so
# resolved's stub is never wired up and DNS breaks at first boot.
printf 'L+! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

mkdir -p /etc/netplan
printf 'network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    all-en:\n      match:\n        name: en*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n    all-eth:\n      match:\n        name: eth*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n' > /etc/netplan/90-default.yaml

# Declare Flathub via /etc/flatpak/remotes.d (not `flatpak remote-add --system`,
# which writes into /var/lib/flatpak and is wiped by the /var reset below).
mkdir -p /etc/flatpak/remotes.d
curl -fsSL https://dl.flathub.org/repo/flathub.flatpakrepo \
    -o /etc/flatpak/remotes.d/flathub.flatpakrepo

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

mkdir -p /usr/lib/sysimage
if [ -d /var/lib/dpkg ]; then cp -a /var/lib/dpkg /usr/lib/sysimage/dpkg; fi

mkdir -p /var/lib
ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg

rm -rf /{boot,home,root,srv,mnt,usr/local,opt}

mkdir -p /sysroot /boot /usr/lib/ostree /var /var/lib

mkdir -p /var/cache/apt/archives/partial
mkdir -p /var/lib/apt/lists/partial
mkdir -p /var/log/apt
mkdir -p /var/lib/sgml-base
mkdir -p /var/lib/xml-core

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT ../var/usrlocal /usr/local
ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg || true

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

mkdir -p /var/tmp

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | tail -n 1)")

# The composefs root is an EROFS image with an overlayfs on top; the initramfs
# has to carry both drivers (plus the filesystems bootc install can format).
# Probe the kernel's module set rather than assuming they exist as modules.
DRIVERS=""
for drv in erofs overlay xfs ext4 btrfs; do
    if find "/usr/lib/modules/${KVER}" -maxdepth 4 -name "${drv}.ko*" -print -quit 2>/dev/null | grep -q .; then
        DRIVERS="${DRIVERS} ${drv}"
    fi
done
if [ -n "$DRIVERS" ]; then
    printf 'add_drivers+="%s "\n' "$DRIVERS" \
        >> /usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf
fi

dracut --force --no-hostonly --reproducible --zstd --verbose --kver "${KVER}" "/usr/lib/modules/${KVER}/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

# bootc install (via skopeo) fails with "no policy.json file found" when the
# base image ships no containers policy. Write a permissive default if absent.
if [ ! -f /etc/containers/policy.json ]; then
    mkdir -p /etc/containers
    printf '{ "default": [ { "type": "insecureAcceptAnything" } ] }\n' \
        > /etc/containers/policy.json
fi

rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

if [ ! -e /var/lib/dpkg ] || { [ -L /var/lib/dpkg ] && [ ! -e /var/lib/dpkg ]; }; then
  mkdir -p /var/lib
  ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg
fi
