#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/arch"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

# Enable the multilib repository (32-bit compatibility libraries on x86_64).
# Recent archlinux base images no longer ship a commented [multilib] section,
# so the old uncomment-only sed was a no-op. Use a robust check-and-append
# approach (matching the holo build scripts).
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
    fi
fi

# Build against the stock pacman layout first: archlinux:latest ships its
# installed packages tracked in /mar/lib/pacman, so /var paths must stay in
# place until after every pacman operation.
mkdir -p /sysroot

pacman -Syu --noconfirm

PACKAGES=(
    base
    glibc-locales
    bash-completion
    bubblewrap
    cpio
    dracut
    efibootmgr
    iwd
    linux
    linux-firmware
    amd-ucode
    intel-ucode
    networkmanager
    ostree
    btrfs-progs
    e2fsprogs
    xfsprogs
    dosfstools
    skopeo
    dbus
    dbus-glib
    glib2
    shadow
    openssh
    sudo
    systemd
    udev
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

setcap cap_setuid+ep /usr/bin/newuidmap && chmod -s /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap && chmod -s /usr/bin/newgidmap

pacman -Scc --noconfirm

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

ln -sT /usr/lib/systemd/system/getty@.service /usr/lib/systemd/system/autovt@.service

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

rm -rf /usr/opt
mv /opt /usr

sed -i '/DisableSandboxNetwork/d' /etc/pacman.conf

find /etc/ -name "*.pacnew" -type f -delete

mkdir -p /usr/lib/systemd/system/sysinit.target.wants \
         /usr/lib/systemd/system/multi-user.target.wants \
         /usr/lib/systemd/system/timers.target.wants \
         /usr/lib/systemd/system/network-online.target.wants \
         /usr/lib/systemd/system/systemd-timesyncd.service.d

# Enable services with /usr symlinks, not `systemctl enable`: in a bootc
# image /etc is machine-local state that gets a three-way merge on upgrade,
# so enablement dropped there is only a first-boot default that a later
# image update cannot reliably re-assert. A /usr symlink tracks the image on
# every upgrade like any other vendored file. `systemctl mask` below is the
# deliberate exception: it must stay in /etc because pacman overwrites /usr
# unit files on upgrade, silently restoring anything masked there.
ln -sfn /usr/lib/systemd/system/systemd-boot-update.service \
    /usr/lib/systemd/system/sysinit.target.wants/systemd-boot-update.service
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
    /usr/lib/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
    /usr/lib/systemd/system/sysinit.target.wants/systemd-resolved.service
ln -sfn /usr/lib/systemd/system/systemd-timesyncd.service \
    /usr/lib/systemd/system/sysinit.target.wants/systemd-timesyncd.service
ln -sfn /usr/lib/systemd/system/arch-bootc-prune-esp.timer \
    /usr/lib/systemd/system/timers.target.wants/arch-bootc-prune-esp.timer

systemctl mask systemd-firstboot.service
systemctl mask systemd-networkd-wait-online.service

ln -sfn /usr/lib/systemd/system/NetworkManager-wait-online.service \
    /usr/lib/systemd/system/network-online.target.wants/NetworkManager-wait-online.service

# timesyncd normally starts early, but NTP/DNS cannot work until the
# network has actually been configured. Pull in network-online.target
# so the initial synchronization does not race NetworkManager.
cat > /usr/lib/systemd/system/systemd-timesyncd.service.d/network.conf <<'EOF'
[Unit]
Wants=network-online.target
After=network-online.target
EOF

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf
printf 'z /etc/resolv.conf 0644 root root -\n' \
    > /usr/lib/tmpfiles.d/resolv-conf-perms.conf

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"

DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

rm -rf /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

# Relocate pacman state into the image: /var is wiped below (and recreated
# empty at runtime) while /usr persists. Shipping the real local DB here lets
# derived images do proper `pacman -Syu` upgrades instead of blind installs
# over untracked files.
mkdir -p /usr/lib/sysimage/var/lib /usr/lib/sysimage/cache/pacman/pkg
cp -a /var/lib/pacman /usr/lib/sysimage/var/lib/pacman
sed -i -e 's|^#DBPath[[:space:]]*=[[:space:]]*/var/lib/pacman/|DBPath = /usr/lib/sysimage/var/lib/pacman/|' \
       -e 's|^#CacheDir[[:space:]]*=[[:space:]]*/var/cache/pacman/pkg/|CacheDir = /usr/lib/sysimage/cache/pacman/pkg/|' \
       /etc/pacman.conf

rm -rf /{boot,home,root,srv,mnt,usr/local}

rm -rf /usr/lib/sysimage/{log,cache/pacman/pkg}

rm -rf /{build,packages}

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sT sysroot/ostree /ostree

ln -sT var/roothome /root

ln -sT var/srv /srv

ln -sT var/mnt /mnt

ln -sT var/opt /opt

ln -sT var/home /home

ln -sT ../var/usrlocal /usr/local
