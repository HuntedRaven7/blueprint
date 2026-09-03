#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/robin"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
    fi
fi

pacman -Syu --noconfirm

PACKAGES=(
    niri
    quickshell
    greetd
    greetd-tuigreet

    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome

    fuzzel
    waybar
    mako
    swaybg
    swayidle
    swaylock
    xwayland-satellite

    qt6-wayland
    qt6-5compat
    qt6-imageformats

    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber

    polkit
    polkit-gnome

    grim
    slurp
    wl-clipboard
    cliphist

    brightnessctl
    playerctl

    ttf-jetbrains-mono-nerd
    ttf-material-symbols-variable-git
    ttf-roboto-flex

    xdg-user-dirs
    xdg-utils

    fish
    git
    rsync
    tmux
    gum
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

echo "::group:: Configure Greetd"

cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --sessions /usr/share/wayland-sessions --asterisks --greeting 'Welcome to robin'"
user = "greeter"
EOF

mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/niri.desktop <<'EOF'
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
TryExec=niri
Type=Application
DesktopNames=niri
EOF

systemctl enable greetd

echo "::endgroup::"

echo "::group:: Configure Quickshell"

mkdir -p /usr/share/quickshell
cat > /usr/share/quickshell/config.kdl <<'EOF'
import Quickshell
import Quickshell.Io

Shell {
    ScreenComponents {
        Bar {}
    }
}
EOF

echo "::endgroup::"

echo "::group:: Configure System"

shopt -s nullglob
mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

mkdir -p /usr/share/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/just/60-custom.just

shopt -u nullglob

useradd -m -G wheel -s /bin/bash robin || true
echo "robin:robin" | chpasswd || true

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl enable greetd
systemctl set-default graphical.target

systemctl --global enable pipewire.socket pipewire.service pipewire-pulse.service wireplumber.service

echo "::endgroup::"

echo "robin build complete!"
